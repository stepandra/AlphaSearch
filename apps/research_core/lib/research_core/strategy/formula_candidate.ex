defmodule ResearchCore.Strategy.FormulaCandidate do
  @moduledoc """
  Formula or formula-like rule extracted from a validated synthesis artifact.
  """

  alias ResearchCore.Strategy.{EvidenceLink, FormulaRole}

  @enforce_keys [
    :id,
    :source_section_ids,
    :supporting_citation_keys,
    :formula_text,
    :exact?,
    :partial?,
    :blocked?,
    :role
  ]
  defstruct [
    :id,
    :formula_text,
    :exact?,
    :partial?,
    :blocked?,
    :role,
    symbol_glossary: %{},
    source_section_ids: [],
    source_section_headings: [],
    supporting_citation_keys: [],
    supporting_record_ids: [],
    evidence_links: [],
    notes: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          formula_text: String.t(),
          exact?: boolean(),
          partial?: boolean(),
          blocked?: boolean(),
          role: FormulaRole.t(),
          symbol_glossary: map(),
          source_section_ids: [atom()],
          source_section_headings: [String.t()],
          supporting_citation_keys: [String.t()],
          supporting_record_ids: [String.t()],
          evidence_links: [EvidenceLink.t()],
          notes: [String.t()]
        }
end
