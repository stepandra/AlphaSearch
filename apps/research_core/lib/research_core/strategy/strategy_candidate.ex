defmodule ResearchCore.Strategy.StrategyCandidate do
  @moduledoc """
  Inspectable intermediate strategy extracted from validated research output.
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
    RuleCandidate,
    StrategyCategory,
    StrategyReadiness,
    ValidationHint
  }

  @enforce_keys [
    :id,
    :title,
    :thesis,
    :category,
    :candidate_kind,
    :market_or_domain_applicability
  ]
  defstruct [
    :id,
    :title,
    :thesis,
    :category,
    :candidate_kind,
    :market_or_domain_applicability,
    :signal_or_rule,
    :entry_condition,
    :exit_condition,
    :expected_edge_source,
    :falsification_idea,
    :readiness,
    :evidence_strength,
    :actionability,
    formula_ids: [],
    rule_candidates: [],
    required_features: [],
    required_datasets: [],
    execution_assumptions: [],
    sizing_assumptions: [],
    evidence_links: [],
    conflicting_evidence_links: [],
    validation_hints: [],
    metric_hints: [],
    notes: [],
    invalidation_reasons: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          thesis: String.t(),
          category: StrategyCategory.t(),
          candidate_kind: CandidateKind.t(),
          market_or_domain_applicability: String.t(),
          signal_or_rule: String.t() | nil,
          entry_condition: String.t() | nil,
          exit_condition: String.t() | nil,
          formula_ids: [String.t()],
          rule_candidates: [RuleCandidate.t()],
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
          readiness: StrategyReadiness.t() | nil,
          evidence_strength: EvidenceStrength.t() | nil,
          actionability: Actionability.t() | nil,
          notes: [String.t()],
          invalidation_reasons: [String.t()]
        }
end
