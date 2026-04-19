defmodule ResearchCore.Strategy.StrategySpec do
  @moduledoc """
  Machine-usable strategy specification ready for downstream review or backtesting handoff.
  """

  alias ResearchCore.Strategy.{
    Actionability,
    CandidateKind,
    DataRequirement,
    EvidenceLink,
    EvidenceStrength,
    ExecutionAssumption,
    FeatureRequirement,
    MetricHint,
    StrategyCategory,
    StrategyReadiness,
    ValidationHint
  }

  @enforce_keys [
    :id,
    :strategy_candidate_id,
    :corpus_snapshot_id,
    :synthesis_run_id,
    :synthesis_artifact_id,
    :title,
    :thesis,
    :category,
    :candidate_kind,
    :market_or_domain_applicability,
    :decision_rule,
    :readiness,
    :evidence_strength,
    :actionability
  ]
  defstruct [
    :id,
    :strategy_candidate_id,
    :strategy_extraction_run_id,
    :corpus_snapshot_id,
    :synthesis_run_id,
    :synthesis_artifact_id,
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
    formula_ids: [],
    required_features: [],
    required_datasets: [],
    execution_assumptions: [],
    sizing_assumptions: [],
    evidence_links: [],
    conflicting_evidence_links: [],
    validation_hints: [],
    metric_hints: [],
    notes: [],
    blocked_by: []
  ]

  @type decision_rule :: %{
          required(:signal_or_rule) => String.t() | nil,
          required(:entry_condition) => String.t() | nil,
          required(:exit_condition) => String.t() | nil,
          required(:formula_ids) => [String.t()],
          required(:rule_ids) => [String.t()]
        }

  @type t :: %__MODULE__{
          id: String.t(),
          strategy_candidate_id: String.t(),
          strategy_extraction_run_id: String.t() | nil,
          corpus_snapshot_id: String.t(),
          synthesis_run_id: String.t(),
          synthesis_artifact_id: String.t(),
          title: String.t(),
          thesis: String.t(),
          category: StrategyCategory.t(),
          candidate_kind: CandidateKind.t(),
          market_or_domain_applicability: String.t(),
          decision_rule: decision_rule(),
          formula_ids: [String.t()],
          required_features: [FeatureRequirement.t()],
          required_datasets: [DataRequirement.t()],
          execution_assumptions: [ExecutionAssumption.t()],
          sizing_assumptions: [ExecutionAssumption.t()],
          evidence_links: [EvidenceLink.t()],
          conflicting_evidence_links: [EvidenceLink.t()],
          expected_edge_source: String.t() | nil,
          validation_hints: [ValidationHint.t()],
          metric_hints: [MetricHint.t()],
          falsification_idea: String.t() | nil,
          readiness: StrategyReadiness.t(),
          evidence_strength: EvidenceStrength.t(),
          actionability: Actionability.t(),
          notes: [String.t()],
          blocked_by: [String.t()]
        }
end
