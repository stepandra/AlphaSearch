defmodule ResearchStore.Artifacts.StrategySpec do
  use Ecto.Schema

  import Ecto.Changeset

  alias ResearchCore.Strategy.{
    Actionability,
    CandidateKind,
    EvidenceStrength,
    StrategyCategory,
    StrategyReadiness
  }

  @category_values Enum.map(StrategyCategory.values(), &Atom.to_string/1)
  @candidate_kind_values Enum.map(CandidateKind.values(), &Atom.to_string/1)
  @readiness_values Enum.map(StrategyReadiness.values(), &Atom.to_string/1)
  @evidence_strength_values Enum.map(EvidenceStrength.values(), &Atom.to_string/1)
  @actionability_values Enum.map(Actionability.values(), &Atom.to_string/1)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "strategy_specs" do
    field(:strategy_candidate_id, :string)
    field(:title, :string)
    field(:thesis, :string)
    field(:category, :string)
    field(:candidate_kind, :string)
    field(:market_or_domain_applicability, :string)
    field(:decision_rule, :map, default: %{})
    field(:expected_edge_source, :string)
    field(:falsification_idea, :string)
    field(:readiness, :string)
    field(:evidence_strength, :string)
    field(:actionability, :string)
    field(:formula_ids, {:array, :string}, default: [])
    field(:required_features, {:array, :map}, default: [])
    field(:required_datasets, {:array, :map}, default: [])
    field(:execution_assumptions, {:array, :map}, default: [])
    field(:sizing_assumptions, {:array, :map}, default: [])
    field(:evidence_links, {:array, :map}, default: [])
    field(:conflicting_evidence_links, {:array, :map}, default: [])
    field(:validation_hints, {:array, :map}, default: [])
    field(:metric_hints, {:array, :map}, default: [])
    field(:notes, {:array, :string}, default: [])
    field(:blocked_by, {:array, :string}, default: [])

    belongs_to(:strategy_extraction_run, ResearchStore.Artifacts.StrategyExtractionRun,
      type: :string
    )

    belongs_to(:corpus_snapshot, ResearchStore.Artifacts.CorpusSnapshot, type: :string)
    belongs_to(:synthesis_run, ResearchStore.Artifacts.SynthesisRun, type: :string)
    belongs_to(:synthesis_artifact, ResearchStore.Artifacts.SynthesisArtifact, type: :string)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(strategy_spec, attrs) do
    strategy_spec
    |> cast(attrs, [
      :id,
      :strategy_extraction_run_id,
      :corpus_snapshot_id,
      :synthesis_run_id,
      :synthesis_artifact_id,
      :strategy_candidate_id,
      :title,
      :thesis,
      :category,
      :candidate_kind,
      :market_or_domain_applicability,
      :decision_rule,
      :expected_edge_source,
      :falsification_idea,
      :readiness,
      :evidence_strength,
      :actionability,
      :formula_ids,
      :required_features,
      :required_datasets,
      :execution_assumptions,
      :sizing_assumptions,
      :evidence_links,
      :conflicting_evidence_links,
      :validation_hints,
      :metric_hints,
      :notes,
      :blocked_by
    ])
    |> validate_required([
      :id,
      :strategy_extraction_run_id,
      :corpus_snapshot_id,
      :synthesis_run_id,
      :synthesis_artifact_id,
      :strategy_candidate_id,
      :title,
      :thesis,
      :category,
      :candidate_kind,
      :market_or_domain_applicability,
      :decision_rule,
      :readiness,
      :evidence_strength,
      :actionability
    ])
    |> validate_inclusion(:category, @category_values)
    |> validate_inclusion(:candidate_kind, @candidate_kind_values)
    |> validate_inclusion(:readiness, @readiness_values)
    |> validate_inclusion(:evidence_strength, @evidence_strength_values)
    |> validate_inclusion(:actionability, @actionability_values)
    |> foreign_key_constraint(:strategy_extraction_run_id)
    |> foreign_key_constraint(:corpus_snapshot_id)
    |> foreign_key_constraint(:synthesis_run_id)
    |> foreign_key_constraint(:synthesis_artifact_id)
  end
end
