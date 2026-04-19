defmodule ResearchCore.Strategy.RuleCandidate do
  @moduledoc """
  Normalized decision rule extracted from synthesis prose.
  """

  alias ResearchCore.Strategy.EvidenceLink

  @enforce_keys [:id, :signal_or_rule]
  defstruct [
    :id,
    :signal_or_rule,
    :entry_condition,
    :exit_condition,
    source_section_ids: [],
    supporting_citation_keys: [],
    evidence_links: [],
    notes: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          signal_or_rule: String.t(),
          entry_condition: String.t() | nil,
          exit_condition: String.t() | nil,
          source_section_ids: [atom()],
          supporting_citation_keys: [String.t()],
          evidence_links: [EvidenceLink.t()],
          notes: [String.t()]
        }
end
