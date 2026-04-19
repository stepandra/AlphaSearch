defmodule ResearchStore do
  @moduledoc """
  Explicit persistence and registry entrypoints for research artifacts.

  The store app owns durable storage for research themes, branch/query plans,
  retrieval outputs, QA artifacts, immutable corpus snapshots, and synthesis
  runs/artifacts derived from those snapshots.
  """

  alias ResearchCore.Corpus.{QAResult, RawRecord}
  alias ResearchCore.Retrieval.RetrievalRun
  alias ResearchCore.Strategy.{ExtractionRun, FormulaCandidate, StrategySpec}
  alias ResearchCore.Strategy.ValidationResult, as: StrategyValidationResult

  alias ResearchCore.Synthesis.{Artifact, Run}
  alias ResearchCore.Synthesis.ValidationResult, as: SynthesisValidationResult

  alias ResearchCore.Theme.{Normalized, Raw}

  alias ResearchStore.{
    Branches,
    CorpusRegistry,
    RetrievalRegistry,
    StrategyRegistry,
    SynthesisRegistry,
    Themes
  }

  @spec store_theme(Raw.t(), Normalized.t()) :: {:ok, map()} | {:error, term()}
  def store_theme(%Raw{} = raw_theme, %Normalized{} = normalized_theme) do
    Themes.store_theme(raw_theme, normalized_theme)
  end

  @spec store_branches(String.t(), list()) :: {:ok, list()} | {:error, term()}
  def store_branches(normalized_theme_id, branches) do
    Branches.store_branches(normalized_theme_id, branches)
  end

  @spec store_run(RetrievalRun.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def store_run(%RetrievalRun{} = run, opts \\ []) do
    RetrievalRegistry.store_run(run, opts)
  end

  @spec store_qa_artifacts([RawRecord.t()], QAResult.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def store_qa_artifacts(raw_records, %QAResult{} = qa_result, opts \\ []) do
    CorpusRegistry.store_qa_artifacts(raw_records, qa_result, opts)
  end

  @spec create_snapshot([RawRecord.t()], QAResult.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def create_snapshot(raw_records, %QAResult{} = qa_result, opts \\ []) do
    CorpusRegistry.create_snapshot(raw_records, qa_result, opts)
  end

  @spec create_synthesis_run(Run.t()) :: {:ok, Run.t()} | {:error, term()}
  def create_synthesis_run(%Run{} = run) do
    SynthesisRegistry.create_run(run)
  end

  @spec update_synthesis_run(String.t(), map()) :: {:ok, Run.t()} | {:error, term()}
  def update_synthesis_run(run_id, attrs) do
    SynthesisRegistry.update_run(run_id, attrs)
  end

  @spec put_synthesis_validation_result(String.t(), SynthesisValidationResult.t()) ::
          {:ok, SynthesisValidationResult.t()} | {:error, term()}
  def put_synthesis_validation_result(run_id, %SynthesisValidationResult{} = validation_result) do
    SynthesisRegistry.put_validation_result(run_id, validation_result)
  end

  @spec put_synthesis_artifact(Artifact.t()) :: {:ok, Artifact.t()} | {:error, term()}
  def put_synthesis_artifact(%Artifact{} = artifact) do
    SynthesisRegistry.put_artifact(artifact)
  end

  @spec latest_synthesis_run_for_snapshot(String.t(), String.t()) :: Run.t() | nil
  def latest_synthesis_run_for_snapshot(snapshot_id, profile_id) do
    SynthesisRegistry.latest_run_for_snapshot(snapshot_id, profile_id)
  end

  @spec get_synthesis_run(String.t()) :: Run.t() | nil
  def get_synthesis_run(run_id), do: SynthesisRegistry.get_run(run_id)

  @spec successful_synthesis_artifact(String.t(), String.t()) :: Artifact.t() | nil
  def successful_synthesis_artifact(snapshot_id, profile_id) do
    SynthesisRegistry.successful_artifact_for_snapshot(snapshot_id, profile_id)
  end

  @spec synthesis_validation_failures(String.t()) :: SynthesisValidationResult.t() | nil
  def synthesis_validation_failures(run_id) do
    SynthesisRegistry.validation_failures(run_id)
  end

  @spec list_snapshot_reports(String.t()) :: [Artifact.t()]
  def list_snapshot_reports(snapshot_id) do
    SynthesisRegistry.list_reports_for_snapshot(snapshot_id)
  end

  @spec latest_branch_report(String.t(), String.t() | nil) :: Artifact.t() | nil
  def latest_branch_report(branch_id, profile_id \\ nil) do
    SynthesisRegistry.latest_report_for_branch(branch_id, profile_id)
  end

  @spec latest_theme_report(String.t(), String.t() | nil) :: Artifact.t() | nil
  def latest_theme_report(theme_id, profile_id \\ nil) do
    SynthesisRegistry.latest_report_for_theme(theme_id, profile_id)
  end

  @spec create_strategy_extraction_run(ExtractionRun.t()) ::
          {:ok, ExtractionRun.t()} | {:error, term()}
  def create_strategy_extraction_run(%ExtractionRun{} = run) do
    StrategyRegistry.create_run(run)
  end

  @spec update_strategy_extraction_run(String.t(), map()) ::
          {:ok, ExtractionRun.t()} | {:error, term()}
  def update_strategy_extraction_run(run_id, attrs) do
    StrategyRegistry.update_run(run_id, attrs)
  end

  @spec put_strategy_validation_result(String.t(), StrategyValidationResult.t()) ::
          {:ok, StrategyValidationResult.t()} | {:error, term()}
  def put_strategy_validation_result(run_id, %StrategyValidationResult{} = validation_result) do
    StrategyRegistry.put_validation_result(run_id, validation_result)
  end

  @spec replace_strategy_formulas(String.t(), [FormulaCandidate.t()]) ::
          {:ok, [FormulaCandidate.t()]} | {:error, term()}
  def replace_strategy_formulas(run_id, formulas) do
    StrategyRegistry.replace_formulas(run_id, formulas)
  end

  @spec replace_strategy_specs(String.t(), [StrategySpec.t()]) ::
          {:ok, [StrategySpec.t()]} | {:error, term()}
  def replace_strategy_specs(run_id, strategy_specs) do
    StrategyRegistry.replace_strategy_specs(run_id, strategy_specs)
  end

  @spec get_strategy_extraction_run(String.t()) :: ExtractionRun.t() | nil
  def get_strategy_extraction_run(run_id), do: StrategyRegistry.get_run(run_id)

  @spec latest_strategy_run_for_snapshot(String.t(), String.t()) :: ExtractionRun.t() | nil
  def latest_strategy_run_for_snapshot(snapshot_id, synthesis_profile_id) do
    StrategyRegistry.latest_run_for_snapshot(snapshot_id, synthesis_profile_id)
  end

  @spec strategy_validation_failures(String.t()) :: StrategyValidationResult.t() | nil
  def strategy_validation_failures(run_id) do
    StrategyRegistry.validation_failures(run_id)
  end

  @spec strategy_formulas_for_run(String.t()) :: [FormulaCandidate.t()]
  def strategy_formulas_for_run(run_id) do
    StrategyRegistry.list_formulas_for_run(run_id)
  end

  @spec strategy_specs_for_run(String.t()) :: [StrategySpec.t()]
  def strategy_specs_for_run(run_id) do
    StrategyRegistry.list_strategy_specs_for_run(run_id)
  end

  @spec strategy_specs_for_snapshot(String.t(), keyword()) :: [StrategySpec.t()]
  def strategy_specs_for_snapshot(snapshot_id, opts \\ []) do
    StrategyRegistry.list_specs_for_snapshot(snapshot_id, opts)
  end

  @spec ready_strategy_specs_for_snapshot(String.t(), keyword()) :: [StrategySpec.t()]
  def ready_strategy_specs_for_snapshot(snapshot_id, opts \\ []) do
    StrategyRegistry.ready_specs_for_snapshot(snapshot_id, opts)
  end

  @spec strategy_specs_for_artifact(String.t(), keyword()) :: [StrategySpec.t()]
  def strategy_specs_for_artifact(artifact_id, opts \\ []) do
    StrategyRegistry.list_specs_for_artifact(artifact_id, opts)
  end

  @spec strategy_specs_for_branch(String.t(), keyword()) :: [StrategySpec.t()]
  def strategy_specs_for_branch(branch_id, opts \\ []) do
    StrategyRegistry.list_specs_for_branch(branch_id, opts)
  end

  @spec strategy_specs_for_theme(String.t(), keyword()) :: [StrategySpec.t()]
  def strategy_specs_for_theme(theme_id, opts \\ []) do
    StrategyRegistry.list_specs_for_theme(theme_id, opts)
  end

  @spec latest_strategy_specs_for_branch(String.t(), keyword()) :: [StrategySpec.t()]
  def latest_strategy_specs_for_branch(branch_id, opts \\ []) do
    StrategyRegistry.latest_specs_for_branch(branch_id, opts)
  end

  @spec latest_strategy_specs_for_theme(String.t(), keyword()) :: [StrategySpec.t()]
  def latest_strategy_specs_for_theme(theme_id, opts \\ []) do
    StrategyRegistry.latest_specs_for_theme(theme_id, opts)
  end

  @spec strategy_formulas_for_spec(String.t()) :: [FormulaCandidate.t()]
  def strategy_formulas_for_spec(spec_id) do
    StrategyRegistry.list_formulas_for_spec(spec_id)
  end

  @spec strategy_spec_with_provenance(String.t()) ::
          %{spec: StrategySpec.t(), formulas: [FormulaCandidate.t()]} | nil
  def strategy_spec_with_provenance(spec_id) do
    StrategyRegistry.get_spec_with_provenance(spec_id)
  end
end
