defmodule ResearchStore.Artifacts.StrategyExtractionRun do
  use Ecto.Schema

  import Ecto.Changeset

  alias ResearchCore.Strategy.RunState

  @state_values Enum.map(RunState.values(), &Atom.to_string/1)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "strategy_extraction_runs" do
    field(:synthesis_profile_id, :string)
    field(:state, :string)
    field(:input_package, :map, default: %{})
    field(:formula_request_spec, :map, default: %{})
    field(:strategy_request_spec, :map, default: %{})
    field(:provider_name, :string)
    field(:provider_model, :string)
    field(:provider_request_id, :string)
    field(:provider_response_id, :string)
    field(:provider_request_hash, :string)
    field(:provider_response_hash, :string)
    field(:provider_metadata, :map, default: %{})
    field(:provider_failure, :map, default: %{})
    field(:raw_provider_output, :map, default: %{})
    field(:started_at, :utc_datetime_usec)
    field(:completed_at, :utc_datetime_usec)

    belongs_to(:corpus_snapshot, ResearchStore.Artifacts.CorpusSnapshot, type: :string)
    belongs_to(:synthesis_run, ResearchStore.Artifacts.SynthesisRun, type: :string)
    belongs_to(:synthesis_artifact, ResearchStore.Artifacts.SynthesisArtifact, type: :string)
    belongs_to(:normalized_theme, ResearchStore.Artifacts.NormalizedTheme, type: :string)
    belongs_to(:research_branch, ResearchStore.Artifacts.ResearchBranch, type: :string)

    has_one(:validation_result, ResearchStore.Artifacts.StrategyValidationResult,
      foreign_key: :strategy_extraction_run_id
    )

    has_many(:formulas, ResearchStore.Artifacts.StrategyFormulaCandidate,
      foreign_key: :strategy_extraction_run_id
    )

    has_many(:strategy_specs, ResearchStore.Artifacts.StrategySpec,
      foreign_key: :strategy_extraction_run_id
    )

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :id,
      :corpus_snapshot_id,
      :synthesis_run_id,
      :synthesis_artifact_id,
      :normalized_theme_id,
      :research_branch_id,
      :synthesis_profile_id,
      :state,
      :input_package,
      :formula_request_spec,
      :strategy_request_spec,
      :provider_name,
      :provider_model,
      :provider_request_id,
      :provider_response_id,
      :provider_request_hash,
      :provider_response_hash,
      :provider_metadata,
      :provider_failure,
      :raw_provider_output,
      :started_at,
      :completed_at
    ])
    |> validate_required([
      :id,
      :corpus_snapshot_id,
      :synthesis_run_id,
      :synthesis_artifact_id,
      :synthesis_profile_id,
      :state
    ])
    |> validate_inclusion(:state, @state_values)
    |> foreign_key_constraint(:corpus_snapshot_id)
    |> foreign_key_constraint(:synthesis_run_id)
    |> foreign_key_constraint(:synthesis_artifact_id)
    |> foreign_key_constraint(:normalized_theme_id)
    |> foreign_key_constraint(:research_branch_id)
  end
end
