defmodule ResearchStore.Artifacts.SynthesisRun do
  use Ecto.Schema

  import Ecto.Changeset

  alias ResearchCore.Synthesis.RunState

  @state_values Enum.map(RunState.all(), &Atom.to_string/1)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "synthesis_runs" do
    field(:profile_id, :string)
    field(:state, :string)
    field(:input_package, :map, default: %{})
    field(:request_spec, :map, default: %{})
    field(:provider_name, :string)
    field(:provider_model, :string)
    field(:provider_request_id, :string)
    field(:provider_response_id, :string)
    field(:provider_request_hash, :string)
    field(:provider_response_hash, :string)
    field(:provider_metadata, :map, default: %{})
    field(:provider_failure, :map, default: %{})
    field(:raw_provider_output, :string)
    field(:started_at, :utc_datetime_usec)
    field(:completed_at, :utc_datetime_usec)

    belongs_to(:corpus_snapshot, ResearchStore.Artifacts.CorpusSnapshot, type: :string)
    belongs_to(:normalized_theme, ResearchStore.Artifacts.NormalizedTheme, type: :string)
    belongs_to(:research_branch, ResearchStore.Artifacts.ResearchBranch, type: :string)

    has_one(:validation_result, ResearchStore.Artifacts.SynthesisValidationResult,
      foreign_key: :synthesis_run_id
    )

    has_one(:artifact, ResearchStore.Artifacts.SynthesisArtifact, foreign_key: :synthesis_run_id)

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :id,
      :corpus_snapshot_id,
      :normalized_theme_id,
      :research_branch_id,
      :profile_id,
      :state,
      :input_package,
      :request_spec,
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
    |> validate_required([:id, :corpus_snapshot_id, :profile_id, :state])
    |> validate_inclusion(:state, @state_values)
    |> foreign_key_constraint(:corpus_snapshot_id)
    |> foreign_key_constraint(:normalized_theme_id)
    |> foreign_key_constraint(:research_branch_id)
  end
end
