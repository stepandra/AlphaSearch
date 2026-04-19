defmodule ResearchJobs.Strategy.Models.StrategyExtractionBatch do
  @moduledoc false

  use Ecto.Schema
  use Instructor.Validator

  import Ecto.Changeset

  alias ResearchJobs.Strategy.Models.StrategyExtractionItem

  @primary_key false
  @type t :: %__MODULE__{}

  embedded_schema do
    embeds_many(:strategies, StrategyExtractionItem)
  end

  @impl true
  def validate_changeset(changeset) do
    cast_embed(changeset, :strategies, required: false)
  end

  @spec to_maps(t()) :: [map()]
  def to_maps(%__MODULE__{strategies: strategies}) do
    Enum.map(strategies, fn strategy ->
      %{
        title: strategy.title,
        thesis: strategy.thesis,
        category: strategy.category,
        candidate_kind: strategy.candidate_kind,
        market_or_domain_applicability: strategy.market_or_domain_applicability,
        direct_signal_or_rule: strategy.direct_signal_or_rule,
        entry_condition: strategy.entry_condition,
        exit_condition: strategy.exit_condition,
        formula_references: strategy.formula_references,
        required_features: strategy.required_features,
        required_datasets: strategy.required_datasets,
        execution_assumptions: strategy.execution_assumptions,
        sizing_assumptions: strategy.sizing_assumptions,
        evidence_references: strategy.evidence_references,
        evidence_pairs: strategy.evidence_pairs,
        conflicting_or_cautionary_evidence: strategy.conflicting_or_cautionary_evidence,
        conflicting_evidence_pairs: strategy.conflicting_evidence_pairs,
        conflict_note: strategy.conflict_note,
        expected_edge_source: strategy.expected_edge_source,
        validation_hints: strategy.validation_hints,
        candidate_metrics: strategy.candidate_metrics,
        falsification_idea: strategy.falsification_idea,
        source_section_ids: strategy.source_section_ids,
        notes: strategy.notes
      }
    end)
  end
end
