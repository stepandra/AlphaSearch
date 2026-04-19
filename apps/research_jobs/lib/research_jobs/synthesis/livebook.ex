defmodule ResearchJobs.Synthesis.Livebook do
  @moduledoc """
  Notebook-facing helpers for explicit synthesis walkthroughs.
  """

  alias ResearchCore.Corpus.{CanonicalRecord, QAResult, RawRecord}
  alias ResearchCore.Synthesis

  alias ResearchCore.Synthesis.{
    Artifact,
    InputPackage,
    PromptBuilder,
    Run,
    Validator,
    ValidationResult
  }

  alias ResearchJobs.Synthesis.{ProviderConfig, ProviderResponse}

  @type bundle :: %{
          required(:snapshot) => map(),
          optional(:accepted_core) => [CanonicalRecord.t()],
          optional(:accepted_analog) => [CanonicalRecord.t()],
          optional(:background) => [CanonicalRecord.t()],
          optional(:quarantine) => list(),
          optional(:duplicate_groups) => list()
        }

  @spec config_summary() :: map()
  def config_summary do
    config = ProviderConfig.config()

    %{
      default_provider: config.default_provider,
      llm: %{
        api_key_env: config.llm.api_key_env,
        api_key_configured?: present_env?(config.llm.api_key_env),
        api_url_env: config.llm.api_url_env,
        api_url: env_or_default(config.llm.api_url_env, config.llm.api_url),
        model_env: config.llm.model_env,
        model: env_or_default(config.llm.model_env, config.llm.default_model),
        temperature: config.llm.temperature
      }
    }
  end

  @spec default_provider() :: module()
  def default_provider do
    ProviderConfig.default_provider()
  end

  @spec build_input_package(bundle(), String.t(), keyword()) ::
          {:ok, InputPackage.t()} | {:error, term()}
  def build_input_package(%{snapshot: _snapshot} = bundle, profile_id, opts \\ [])
      when is_binary(profile_id) do
    with {:ok, profile} <- Synthesis.profile(profile_id) do
      opts = maybe_put_provenance_summaries(opts)
      ResearchCore.Synthesis.InputBuilder.build(profile, bundle, opts)
    end
  end

  @spec build_input_package!(bundle(), String.t(), keyword()) :: InputPackage.t()
  def build_input_package!(bundle, profile_id, opts \\ []) do
    case build_input_package(bundle, profile_id, opts) do
      {:ok, %InputPackage{} = input_package} -> input_package
      {:error, reason} -> raise ArgumentError, "synthesis input build failed: #{inspect(reason)}"
    end
  end

  @spec build_request(String.t(), InputPackage.t()) :: map()
  def build_request(profile_id, %InputPackage{} = input_package) when is_binary(profile_id) do
    profile_id
    |> Synthesis.profile!()
    |> PromptBuilder.build(input_package)
  end

  @spec run_provider(map(), keyword()) :: {:ok, ProviderResponse.t()} | {:error, term()}
  def run_provider(request_spec, opts \\ []) when is_map(request_spec) do
    provider = Keyword.get(opts, :provider, ProviderConfig.default_provider())
    provider_opts = Keyword.get(opts, :provider_opts, [])
    provider.synthesize(request_spec, provider_opts)
  end

  @spec validate(String.t(), InputPackage.t(), String.t()) :: ValidationResult.t()
  def validate(profile_id, %InputPackage{} = input_package, markdown)
      when is_binary(profile_id) and is_binary(markdown) do
    profile_id
    |> Synthesis.profile!()
    |> Validator.validate(input_package, markdown)
  end

  @spec build_context(
          bundle(),
          String.t(),
          InputPackage.t(),
          map(),
          ProviderResponse.t(),
          ValidationResult.t(),
          keyword()
        ) :: map()
  def build_context(
        %{snapshot: snapshot} = bundle,
        profile_id,
        %InputPackage{} = input_package,
        request_spec,
        %ProviderResponse{} = provider_response,
        %ValidationResult{} = validation_result,
        opts \\ []
      )
      when is_binary(profile_id) and is_map(request_spec) do
    started_at = Keyword.get(opts, :started_at, timestamp())
    completed_at = validation_result.validated_at || Keyword.get(opts, :completed_at, timestamp())
    run_id = Keyword.get(opts, :run_id, run_id(snapshot.id, profile_id, started_at))

    validation_result = %ValidationResult{
      validation_result
      | synthesis_run_id: run_id,
        validated_at: validation_result.validated_at || completed_at
    }

    artifact =
      if validation_result.valid? do
        artifact_id =
          Keyword.get(
            opts,
            :artifact_id,
            artifact_id(run_id, profile_id, provider_response.content)
          )

        %Artifact{
          id: artifact_id,
          synthesis_run_id: run_id,
          corpus_snapshot_id: snapshot.id,
          profile_id: profile_id,
          format: :markdown,
          content: provider_response.content,
          artifact_hash: hash(provider_response.content),
          finalized_at: validation_result.validated_at,
          section_headings: Validator.extract_headings(provider_response.content),
          cited_keys: validation_result.cited_keys,
          summary: %{
            package_digest: input_package.digest,
            valid?: true,
            citation_count: length(validation_result.cited_keys)
          }
        }
      end

    state = if(validation_result.valid?, do: :completed, else: :validation_failed)

    synthesis_run = %Run{
      id: run_id,
      corpus_snapshot_id: snapshot.id,
      normalized_theme_id: snapshot.normalized_theme_ids |> List.first(),
      research_branch_id: snapshot.branch_ids |> List.first(),
      profile_id: profile_id,
      state: state,
      input_package: input_package,
      request_spec: request_spec,
      provider_name: provider_response.provider,
      provider_model: provider_response.model,
      provider_request_id: provider_response.request_id,
      provider_response_id: provider_response.response_id,
      provider_request_hash: provider_response.request_hash,
      provider_response_hash: provider_response.response_hash,
      provider_metadata: provider_response.metadata,
      raw_provider_output: provider_response.content,
      started_at: started_at,
      completed_at: completed_at,
      validation_result: validation_result,
      artifact: artifact
    }

    %{
      bundle: bundle,
      synthesis_run: synthesis_run,
      artifact: artifact,
      validation_result: validation_result
    }
  end

  @spec build_strategy_context(map()) ::
          {:ok,
           %{
             required(:bundle) => bundle(),
             required(:synthesis_run) => Run.t(),
             required(:artifact) => Artifact.t(),
             required(:validation_result) => ValidationResult.t()
           }}
          | {:error, term()}
  def build_strategy_context(%{
        bundle: %{snapshot: _snapshot} = bundle,
        synthesis_run: %Run{} = synthesis_run,
        artifact: %Artifact{} = artifact,
        validation_result: %ValidationResult{valid?: true} = validation_result
      }) do
    {:ok,
     %{
       bundle: bundle,
       synthesis_run: synthesis_run,
       artifact: artifact,
       validation_result: validation_result
     }}
  end

  def build_strategy_context(%{artifact: nil}), do: {:error, :missing_validated_artifact}

  def build_strategy_context(%{validation_result: %{valid?: false}}),
    do: {:error, :invalid_synthesis_result}

  def build_strategy_context(_context), do: {:error, :invalid_context}

  defp maybe_put_provenance_summaries(opts) do
    if Keyword.has_key?(opts, :provenance_summaries) do
      opts
    else
      raw_records = Keyword.get(opts, :raw_records)
      qa_result = Keyword.get(opts, :qa_result)

      case provenance_summaries(raw_records, qa_result) do
        nil -> opts
        summaries -> Keyword.put(opts, :provenance_summaries, summaries)
      end
    end
  end

  defp provenance_summaries(raw_records, %QAResult{} = qa_result) when is_list(raw_records) do
    records_by_id = Map.new(raw_records, &{&1.id, &1})

    (qa_result.accepted_core ++ qa_result.accepted_analog ++ qa_result.background)
    |> Map.new(fn %CanonicalRecord{} = record ->
      decisions =
        qa_result.decision_log
        |> Enum.filter(fn decision ->
          decision.canonical_record_id == record.id or decision.record_id == record.id
        end)

      raw_record_summaries =
        record.raw_record_ids
        |> Enum.map(&Map.get(records_by_id, &1))
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&raw_record_summary/1)

      {record.id, %{raw_records: raw_record_summaries, decisions: decisions}}
    end)
  end

  defp provenance_summaries(_raw_records, _qa_result), do: nil

  defp raw_record_summary(%RawRecord{} = raw_record) do
    %{
      id: raw_record.id,
      retrieval_run_id: raw_record.retrieval_run_id,
      raw_fields: raw_record.raw_fields
    }
  end

  defp present_env?(env_name), do: env_or_default(env_name, nil) not in [nil, ""]

  defp env_or_default(nil, default), do: default
  defp env_or_default(env_name, default), do: System.get_env(env_name) || default

  defp run_id(snapshot_id, profile_id, started_at) do
    stable_id("synthesis_run", [snapshot_id, profile_id, DateTime.to_iso8601(started_at)])
  end

  defp artifact_id(run_id, profile_id, markdown) do
    stable_id("synthesis_artifact", [run_id, profile_id, markdown])
  end

  defp stable_id(prefix, parts) do
    parts
    |> Enum.map(&to_string/1)
    |> Enum.join(":")
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 24)
    |> then(&"#{prefix}_#{&1}")
  end

  defp hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end
end
