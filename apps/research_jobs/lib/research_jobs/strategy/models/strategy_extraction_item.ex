defmodule ResearchJobs.Strategy.Models.StrategyExtractionItem do
  @moduledoc false

  use Ecto.Schema
  use Instructor.Validator

  import Ecto.Changeset

  @primary_key false
  @type t :: %__MODULE__{}

  embedded_schema do
    field(:title, :string)
    field(:thesis, :string)

    field(:category, Ecto.Enum,
      values: [
        :calibration_strategy,
        :execution_strategy,
        :coherence_arbitrage_strategy,
        :sizing_strategy,
        :behavioral_filter_strategy,
        :analog_transfer_strategy,
        :market_structure_strategy
      ]
    )

    field(:candidate_kind, Ecto.Enum,
      values: [
        :directly_specified_strategy,
        :formula_backed_incomplete_strategy,
        :analog_transfer_candidate,
        :speculative_not_backtestable
      ]
    )

    field(:market_or_domain_applicability, :string)
    field(:direct_signal_or_rule, :string)
    field(:entry_condition, :string)
    field(:exit_condition, :string)
    field(:formula_references, {:array, :string}, default: [])
    field(:required_features, {:array, :map}, default: [])
    field(:required_datasets, {:array, :map}, default: [])
    field(:execution_assumptions, {:array, :map}, default: [])
    field(:sizing_assumptions, {:array, :map}, default: [])
    field(:evidence_references, {:array, :string}, default: [])
    field(:evidence_pairs, {:array, :map}, default: [])
    field(:conflicting_or_cautionary_evidence, {:array, :string}, default: [])
    field(:conflicting_evidence_pairs, {:array, :map}, default: [])
    field(:conflict_note, :string)
    field(:expected_edge_source, :string)
    field(:validation_hints, {:array, :map}, default: [])
    field(:candidate_metrics, {:array, :map}, default: [])
    field(:falsification_idea, :string)
    field(:source_section_ids, {:array, :string}, default: [])
    field(:notes, {:array, :string}, default: [])
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :title,
      :thesis,
      :category,
      :candidate_kind,
      :market_or_domain_applicability,
      :direct_signal_or_rule,
      :entry_condition,
      :exit_condition,
      :formula_references,
      :required_features,
      :required_datasets,
      :execution_assumptions,
      :sizing_assumptions,
      :evidence_references,
      :evidence_pairs,
      :conflicting_or_cautionary_evidence,
      :conflicting_evidence_pairs,
      :conflict_note,
      :expected_edge_source,
      :validation_hints,
      :candidate_metrics,
      :falsification_idea,
      :source_section_ids,
      :notes
    ])
    |> validate_changeset()
  end

  @impl true
  def validate_changeset(changeset) do
    changeset
    |> validate_required([
      :title,
      :thesis,
      :category,
      :candidate_kind,
      :market_or_domain_applicability
    ])
    |> validate_length(:source_section_ids, min: 1)
    |> validate_length(:evidence_references, min: 1)
  end
end
