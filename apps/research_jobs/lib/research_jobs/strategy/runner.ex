defmodule ResearchJobs.Strategy.Runner do
  @moduledoc """
  Orchestrates strategy-spec extraction from a finalized snapshot and validated synthesis artifact.
  """

  alias ResearchCore.Strategy
  alias ResearchCore.Canonical
  alias ResearchCore.Strategy.{ExtractionRun, FormulaNormalizer}
  alias ResearchJobs.Strategy.Models.{FormulaExtractionBatch, StrategyExtractionBatch}
  alias ResearchJobs.Strategy.ProviderConfig
  alias ResearchJobs.Strategy.PromptBuilder
  alias ResearchJobs.Strategy.ProviderError
  alias ResearchStore.{CorpusRegistry, StrategyRegistry, SynthesisRegistry}

  @options_schema [
    provider: [type: :atom, default: ProviderConfig.default_provider()],
    provider_opts: [type: :keyword_list, default: []],
    normalized_theme_id: [type: :string],
    research_branch_id: [type: :string],
    branch_context: [type: :map],
    theme_context: [type: :map]
  ]

  @spec run(String.t(), String.t(), keyword()) ::
          {:ok, ExtractionRun.t()} | {:error, ExtractionRun.t()} | {:error, term()}
  def run(snapshot_id, synthesis_profile_id, opts \\ [])
      when is_binary(snapshot_id) and is_binary(synthesis_profile_id) do
    with {:ok, opts} <- NimbleOptions.validate(opts, @options_schema),
         {:ok, bundle} <- CorpusRegistry.load_snapshot(snapshot_id),
         %ResearchCore.Synthesis.Artifact{} = artifact <-
           SynthesisRegistry.successful_artifact_for_snapshot(snapshot_id, synthesis_profile_id),
         %ResearchCore.Synthesis.Run{} = synthesis_run <-
           SynthesisRegistry.get_run(artifact.synthesis_run_id),
         {:ok, input_package} <-
           Strategy.build_input_package(
             bundle,
             synthesis_run,
             artifact,
             synthesis_run.validation_result,
             branch_context: opts[:branch_context],
             theme_context: opts[:theme_context]
           ),
         formula_request_spec <- PromptBuilder.build_formula_request(input_package),
         {:ok, %ExtractionRun{} = run} <-
           create_run(bundle, input_package, formula_request_spec, opts) do
      execute_provider(run, input_package, formula_request_spec, opts)
    else
      nil -> {:error, {:missing_validated_synthesis_artifact, snapshot_id, synthesis_profile_id}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_provider(run, input_package, formula_request_spec, opts) do
    provider = opts[:provider]
    provider_opts = opts[:provider_opts]

    with {:ok, _running_run} <- StrategyRegistry.update_run(run.id, %{state: :running}),
         {:ok, formula_response} <- provider.extract_formulas(formula_request_spec, provider_opts),
         raw_formula_candidates <- FormulaExtractionBatch.to_maps(formula_response.content),
         %{accepted: normalized_formulas} <-
           FormulaNormalizer.normalize(input_package, raw_formula_candidates),
         strategy_request_spec <-
           PromptBuilder.build_strategy_request(input_package, normalized_formulas),
         {:ok, _run_with_strategy_spec} <-
           StrategyRegistry.update_run(run.id, %{
             strategy_request_spec: strategy_request_spec,
             provider_name: formula_response.provider,
             provider_model: formula_response.model
           }),
         {:ok, strategy_response} <-
           provider.extract_strategies(strategy_request_spec, provider_opts),
         raw_strategy_candidates <- StrategyExtractionBatch.to_maps(strategy_response.content),
         {:ok, normalized} <-
           Strategy.normalize(
             input_package,
             raw_formula_candidates,
             raw_strategy_candidates,
             strategy_extraction_run_id: run.id
           ),
         validation = normalized.validation,
         {:ok, _validation} <- StrategyRegistry.put_validation_result(run.id, validation) do
      finalize_run(
        run.id,
        normalized,
        validation,
        formula_response,
        strategy_response,
        strategy_request_spec
      )
    else
      {:error, %ProviderError{} = error} ->
        fail_provider(run.id, error)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp finalize_run(
         run_id,
         normalized,
         validation,
         formula_response,
         strategy_response,
         strategy_request_spec
       ) do
    provider_attrs = provider_attrs(formula_response, strategy_response)
    raw_provider_output = raw_provider_output(formula_response, strategy_response)

    if validation.valid? do
      with {:ok, _formulas} <- StrategyRegistry.replace_formulas(run_id, normalized.formulas),
           {:ok, _specs} <- StrategyRegistry.replace_strategy_specs(run_id, normalized.specs),
           {:ok, _run} <-
             StrategyRegistry.update_run(run_id, %{
               state: :completed,
               completed_at: timestamp(),
               strategy_request_spec: strategy_request_spec,
               provider_name: provider_attrs.provider_name,
               provider_model: provider_attrs.provider_model,
               provider_request_id: provider_attrs.provider_request_id,
               provider_response_id: provider_attrs.provider_response_id,
               provider_request_hash: provider_attrs.provider_request_hash,
               provider_response_hash: provider_attrs.provider_response_hash,
               provider_metadata: provider_attrs.provider_metadata,
               raw_provider_output: raw_provider_output
             }) do
        {:ok, StrategyRegistry.get_run!(run_id)}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, _failed_run} =
        StrategyRegistry.update_run(run_id, %{
          state: :validation_failed,
          completed_at: timestamp(),
          strategy_request_spec: strategy_request_spec,
          provider_name: provider_attrs.provider_name,
          provider_model: provider_attrs.provider_model,
          provider_request_id: provider_attrs.provider_request_id,
          provider_response_id: provider_attrs.provider_response_id,
          provider_request_hash: provider_attrs.provider_request_hash,
          provider_response_hash: provider_attrs.provider_response_hash,
          provider_metadata: provider_attrs.provider_metadata,
          raw_provider_output: raw_provider_output
        })

      {:error, StrategyRegistry.get_run!(run_id)}
    end
  end

  defp fail_provider(run_id, error) do
    {:ok, _failed_run} =
      StrategyRegistry.update_run(run_id, %{
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

    {:error, StrategyRegistry.get_run!(run_id)}
  end

  defp create_run(bundle, input_package, formula_request_spec, opts) do
    now = timestamp()

    run = %ExtractionRun{
      id: run_id(input_package.corpus_snapshot_id, input_package.synthesis_artifact_id, now),
      corpus_snapshot_id: input_package.corpus_snapshot_id,
      synthesis_run_id: input_package.synthesis_run_id,
      synthesis_artifact_id: input_package.synthesis_artifact_id,
      synthesis_profile_id: input_package.synthesis_profile_id,
      normalized_theme_id: derive_theme_id(bundle.snapshot, opts),
      research_branch_id: derive_branch_id(bundle.snapshot, opts),
      state: :pending,
      input_package: input_package,
      formula_request_spec: formula_request_spec,
      provider_name: provider_id(opts[:provider]),
      started_at: now
    }

    StrategyRegistry.create_run(run)
  end

  defp derive_theme_id(snapshot, opts) do
    opts[:normalized_theme_id] ||
      case snapshot.normalized_theme_ids do
        [theme_id] -> theme_id
        _ -> nil
      end
  end

  defp derive_branch_id(snapshot, opts) do
    opts[:research_branch_id] ||
      case snapshot.branch_ids do
        [branch_id] -> branch_id
        _ -> nil
      end
  end

  defp provider_attrs(formula_response, strategy_response) do
    %{
      provider_name: strategy_response.provider || formula_response.provider,
      provider_model: strategy_response.model || formula_response.model,
      provider_request_id: strategy_response.request_id || formula_response.request_id,
      provider_response_id: strategy_response.response_id || formula_response.response_id,
      provider_request_hash: strategy_response.request_hash || formula_response.request_hash,
      provider_response_hash: strategy_response.response_hash || formula_response.response_hash,
      provider_metadata: %{
        formula_phase: formula_response.metadata,
        strategy_phase: strategy_response.metadata
      }
    }
  end

  defp raw_provider_output(formula_response, strategy_response) do
    %{
      formula_phase: FormulaExtractionBatch.to_maps(formula_response.content),
      strategy_phase: StrategyExtractionBatch.to_maps(strategy_response.content)
    }
  end

  defp run_id(snapshot_id, artifact_id, started_at) do
    entropy = System.unique_integer([:positive])

    :crypto.hash(
      :sha256,
      "#{snapshot_id}:#{artifact_id}:#{DateTime.to_iso8601(started_at)}:#{entropy}"
    )
    |> Base.encode16(case: :lower)
    |> binary_part(0, 24)
    |> then(&"strategy_extraction_run_#{&1}")
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end

  defp provider_id(value) when is_atom(value), do: Atom.to_string(value)
  defp provider_id(value) when is_binary(value), do: value
  defp provider_id(value), do: Canonical.hash(value)
end
