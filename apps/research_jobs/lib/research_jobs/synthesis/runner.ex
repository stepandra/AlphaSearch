defmodule ResearchJobs.Synthesis.Runner do
  @moduledoc """
  Orchestrates synthesis from finalized snapshot to validated report artifact.
  """

  alias ResearchCore.Synthesis
  alias ResearchCore.Canonical
  alias ResearchCore.Synthesis.{Artifact, InputBuilder, PromptBuilder, Run, Validator}
  alias ResearchJobs.Synthesis.ProviderConfig
  alias ResearchJobs.Synthesis.ProviderResponse
  alias ResearchStore.{CorpusRegistry, SynthesisRegistry}

  @spec run(String.t(), String.t(), keyword()) ::
          {:ok, Run.t()} | {:error, Run.t()} | {:error, term()}
  def run(snapshot_id, profile_id, opts \\ [])
      when is_binary(snapshot_id) and is_binary(profile_id) do
    provider = Keyword.get(opts, :provider, ProviderConfig.default_provider())
    provider_opts = Keyword.get(opts, :provider_opts, [])

    with {:ok, profile} <- Synthesis.profile(profile_id),
         {:ok, bundle} <- CorpusRegistry.load_snapshot(snapshot_id),
         provenance_summaries <- provenance_summaries(bundle, profile, opts),
         {:ok, package} <-
           InputBuilder.build(profile, bundle,
             include_background?: Keyword.get(opts, :include_background?, true),
             include_quarantine_summary?: Keyword.get(opts, :include_quarantine_summary?, false),
             provenance_summaries: provenance_summaries
           ),
         request_spec <- PromptBuilder.build(profile, package),
         {:ok, %Run{} = run} <-
           create_run(bundle, profile_id, package, request_spec, provider, opts),
         {:ok, _running_run} <-
           SynthesisRegistry.update_run(run.id, %{state: :running, started_at: run.started_at}) do
      execute_provider(run, profile, package, request_spec, provider, provider_opts)
    end
  end

  defp execute_provider(run, profile, package, request_spec, provider, provider_opts) do
    case provider.synthesize(request_spec, provider_opts) do
      {:ok, %ProviderResponse{} = response} ->
        persist_provider_response(run, response)
        validation = Validator.validate(profile, package, response.content)
        {:ok, _validation} = SynthesisRegistry.put_validation_result(run.id, validation)

        if validation.valid? do
          artifact = build_artifact(run, package, response.content, validation)

          with {:ok, _artifact} <- SynthesisRegistry.put_artifact(artifact),
               {:ok, _completed} <-
                 SynthesisRegistry.update_run(run.id, %{
                   state: :completed,
                   completed_at: artifact.finalized_at
                 }) do
            {:ok, SynthesisRegistry.get_run!(run.id)}
          else
            {:error, reason} -> {:error, reason}
          end
        else
          {:ok, _failed_run} =
            SynthesisRegistry.update_run(run.id, %{
              state: :validation_failed,
              completed_at: validation.validated_at
            })

          {:error, SynthesisRegistry.get_run!(run.id)}
        end

      {:error, error} ->
        {:ok, _failed_run} =
          SynthesisRegistry.update_run(run.id, %{
            state: :provider_failed,
            completed_at: timestamp(),
            provider_failure: %{
              provider: error.provider,
              reason: error.reason,
              message: error.message,
              details: error.details,
              retryable?: error.retryable?
            }
          })

        {:error, SynthesisRegistry.get_run!(run.id)}
    end
  end

  defp persist_provider_response(run, response) do
    SynthesisRegistry.update_run(run.id, %{
      provider_name: response.provider,
      provider_model: response.model,
      provider_request_id: response.request_id,
      provider_response_id: response.response_id,
      provider_request_hash: response.request_hash,
      provider_response_hash: response.response_hash,
      provider_metadata: response.metadata,
      raw_provider_output: response.content
    })
  end

  defp build_artifact(run, package, markdown, validation) do
    finalized_at = validation.validated_at || timestamp()

    %Artifact{
      id: artifact_id(run.id, package.profile_id, markdown),
      synthesis_run_id: run.id,
      corpus_snapshot_id: run.corpus_snapshot_id,
      profile_id: package.profile_id,
      format: :markdown,
      content: markdown,
      artifact_hash: hash(markdown),
      finalized_at: finalized_at,
      section_headings: Validator.extract_headings(markdown),
      cited_keys: validation.cited_keys,
      summary: %{
        package_digest: package.digest,
        valid?: validation.valid?,
        citation_count: length(validation.cited_keys)
      }
    }
  end

  defp create_run(bundle, profile_id, package, request_spec, provider, opts) do
    now = timestamp()

    run = %Run{
      id: run_id(bundle.snapshot.id, profile_id, now),
      corpus_snapshot_id: bundle.snapshot.id,
      normalized_theme_id: derive_theme_id(bundle.snapshot, opts),
      research_branch_id: derive_branch_id(bundle.snapshot, opts),
      profile_id: profile_id,
      state: :pending,
      input_package: package,
      request_spec: request_spec,
      provider_name: provider_id(provider),
      started_at: now
    }

    SynthesisRegistry.create_run(run)
  end

  defp provenance_summaries(bundle, profile, opts) do
    records =
      bundle.accepted_core ++
        bundle.accepted_analog ++
        if(profile.include_background? and Keyword.get(opts, :include_background?, true),
          do: bundle.background,
          else: []
        )

    Map.new(records, fn record ->
      {:ok, provenance} = CorpusRegistry.provenance_summary(record.id)
      {record.id, provenance}
    end)
  end

  defp derive_theme_id(snapshot, opts) do
    Keyword.get(opts, :normalized_theme_id) ||
      case snapshot.normalized_theme_ids do
        [theme_id] -> theme_id
        _ -> nil
      end
  end

  defp derive_branch_id(snapshot, opts) do
    Keyword.get(opts, :research_branch_id) || Keyword.get(opts, :branch_id) ||
      case snapshot.branch_ids do
        [branch_id] -> branch_id
        _ -> nil
      end
  end

  defp run_id(snapshot_id, profile_id, started_at) do
    entropy = System.unique_integer([:positive])

    hash("#{snapshot_id}:#{profile_id}:#{DateTime.to_iso8601(started_at)}:#{entropy}")
    |> binary_part(0, 24)
    |> then(&"synthesis_run_#{&1}")
  end

  defp artifact_id(run_id, profile_id, markdown) do
    hash("#{run_id}:#{profile_id}:#{markdown}")
    |> binary_part(0, 24)
    |> then(&"synthesis_artifact_#{&1}")
  end

  defp hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end

  defp provider_id(value) when is_atom(value), do: Atom.to_string(value)
  defp provider_id(value) when is_binary(value), do: value
  defp provider_id(value), do: Canonical.hash(value)
end
