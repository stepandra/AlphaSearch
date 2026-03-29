defmodule ResearchCore.Corpus.CanonicalRecord do
  @moduledoc """
  Canonicalized corpus record emitted by the QA layer.
  """

  alias ResearchCore.Corpus.{
    AcceptanceDecision,
    FormulaCompletenessStatus,
    RecordClassification,
    SourceIdentifiers,
    SourceProvenanceSummary
  }

  @enforce_keys [
    :id,
    :canonical_title,
    :identifiers,
    :formula_completeness_status,
    :source_provenance_summary
  ]
  defstruct [
    :id,
    :canonical_title,
    :canonical_citation,
    :canonical_url,
    :year,
    :source_type,
    :abstract,
    :content_excerpt,
    :methodology_summary,
    :findings_summary,
    :limitations_summary,
    :direct_product_implication,
    :market_type,
    :classification,
    :formula_completeness_status,
    :source_provenance_summary,
    authors: [],
    identifiers: %SourceIdentifiers{},
    relevance_score: 0,
    evidence_strength_score: 0,
    transferability_score: 0,
    citation_quality_score: 0,
    formula_actionability_score: 0,
    external_validity_risk: :unknown,
    venue_specificity_flag: false,
    raw_record_ids: [],
    normalized_fields: %{},
    qa_decisions: []
  ]

  @type source_type ::
          :journal_article
          | :working_paper
          | :preprint
          | :conference_paper
          | :official_documentation
          | :official_site
          | :report
          | :web_page
          | :unknown

  @type t :: %__MODULE__{
          id: String.t(),
          canonical_title: String.t(),
          canonical_citation: String.t() | nil,
          canonical_url: String.t() | nil,
          year: pos_integer() | nil,
          authors: [String.t()],
          source_type: source_type() | nil,
          identifiers: SourceIdentifiers.t(),
          abstract: String.t() | nil,
          content_excerpt: String.t() | nil,
          methodology_summary: String.t() | nil,
          findings_summary: String.t() | nil,
          limitations_summary: String.t() | nil,
          direct_product_implication: String.t() | nil,
          market_type: String.t() | nil,
          relevance_score: 0..5,
          evidence_strength_score: 0..5,
          transferability_score: 0..5,
          citation_quality_score: 0..5,
          formula_actionability_score: 0..5,
          external_validity_risk: :low | :medium | :high | :unknown,
          venue_specificity_flag: boolean(),
          classification: RecordClassification.t() | nil,
          formula_completeness_status: FormulaCompletenessStatus.t(),
          source_provenance_summary: SourceProvenanceSummary.t(),
          raw_record_ids: [String.t()],
          normalized_fields: map(),
          qa_decisions: [AcceptanceDecision.t()]
        }
end
