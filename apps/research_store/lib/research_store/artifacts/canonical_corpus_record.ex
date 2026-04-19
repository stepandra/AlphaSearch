defmodule ResearchStore.Artifacts.CanonicalCorpusRecord do
  use Ecto.Schema

  import Ecto.Changeset

  alias ResearchCore.Corpus.{FormulaCompletenessStatus, RecordClassification}

  @classification_values Enum.map(RecordClassification.all(), &Atom.to_string/1)
  @formula_values Enum.map(FormulaCompletenessStatus.all(), &Atom.to_string/1)
  @risk_values ~w(low medium high unknown)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "canonical_corpus_records" do
    field(:canonical_title, :string)
    field(:canonical_citation, :string)
    field(:canonical_url, :string)
    field(:year, :integer)
    field(:authors, {:array, :string}, default: [])
    field(:source_type, :string)
    field(:doi, :string)
    field(:arxiv, :string)
    field(:ssrn, :string)
    field(:nber, :string)
    field(:osf, :string)
    field(:source_url, :string)
    field(:abstract, :string)
    field(:content_excerpt, :string)
    field(:methodology_summary, :string)
    field(:findings_summary, :string)
    field(:limitations_summary, :string)
    field(:direct_product_implication, :string)
    field(:market_type, :string)
    field(:classification, :string)
    field(:formula_completeness_status, :string)
    field(:relevance_score, :integer, default: 0)
    field(:evidence_strength_score, :integer, default: 0)
    field(:transferability_score, :integer, default: 0)
    field(:citation_quality_score, :integer, default: 0)
    field(:formula_actionability_score, :integer, default: 0)
    field(:external_validity_risk, :string, default: "unknown")
    field(:venue_specificity_flag, :boolean, default: false)
    field(:raw_record_ids, {:array, :string}, default: [])
    field(:normalized_fields, :map, default: %{})
    field(:provenance_providers, {:array, :string}, default: [])
    field(:provenance_retrieval_run_ids, {:array, :string}, default: [])
    field(:provenance_raw_record_ids, {:array, :string}, default: [])
    field(:provenance_query_texts, {:array, :string}, default: [])
    field(:provenance_source_urls, {:array, :string}, default: [])
    field(:provenance_branch_kinds, {:array, :string}, default: [])
    field(:provenance_branch_labels, {:array, :string}, default: [])
    field(:provenance_merged_from_canonical_ids, {:array, :string}, default: [])

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :id,
      :canonical_title,
      :canonical_citation,
      :canonical_url,
      :year,
      :authors,
      :source_type,
      :doi,
      :arxiv,
      :ssrn,
      :nber,
      :osf,
      :source_url,
      :abstract,
      :content_excerpt,
      :methodology_summary,
      :findings_summary,
      :limitations_summary,
      :direct_product_implication,
      :market_type,
      :classification,
      :formula_completeness_status,
      :relevance_score,
      :evidence_strength_score,
      :transferability_score,
      :citation_quality_score,
      :formula_actionability_score,
      :external_validity_risk,
      :venue_specificity_flag,
      :raw_record_ids,
      :normalized_fields,
      :provenance_providers,
      :provenance_retrieval_run_ids,
      :provenance_raw_record_ids,
      :provenance_query_texts,
      :provenance_source_urls,
      :provenance_branch_kinds,
      :provenance_branch_labels,
      :provenance_merged_from_canonical_ids
    ])
    |> validate_required([:id, :canonical_title, :formula_completeness_status])
    |> validate_inclusion(:classification, @classification_values)
    |> validate_inclusion(:formula_completeness_status, @formula_values)
    |> validate_inclusion(:external_validity_risk, @risk_values)
    |> validate_number(:relevance_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
    |> validate_number(:evidence_strength_score,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 5
    )
    |> validate_number(:transferability_score,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 5
    )
    |> validate_number(:citation_quality_score,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 5
    )
    |> validate_number(:formula_actionability_score,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 5
    )
  end
end
