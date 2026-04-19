defmodule ResearchCore.Synthesis.InputPackage do
  @moduledoc """
  Deterministic synthesis payload derived from a finalized corpus snapshot.
  """

  alias ResearchCore.Synthesis.CitationKey

  @enforce_keys [:snapshot_id, :snapshot_finalized_at, :profile_id, :citation_keys, :digest]
  defstruct [
    :snapshot_id,
    :snapshot_label,
    :snapshot_finalized_at,
    :profile_id,
    :digest,
    normalized_theme_ids: [],
    branch_ids: [],
    retrieval_run_ids: [],
    accepted_core: [],
    accepted_analog: [],
    background: [],
    quarantine_summary: [],
    citation_keys: [],
    provenance_references: %{},
    excluded_inputs: []
  ]

  @type packaged_record :: %{
          required(:record_id) => String.t(),
          required(:classification) => :accepted_core | :accepted_analog | :background,
          required(:citation_key) => String.t(),
          required(:title) => String.t(),
          required(:citation) => String.t() | nil,
          required(:year) => integer() | nil,
          required(:authors) => [String.t()],
          required(:source_type) => atom() | nil,
          required(:abstract) => String.t() | nil,
          required(:methodology_summary) => String.t() | nil,
          required(:findings_summary) => String.t() | nil,
          required(:limitations_summary) => String.t() | nil,
          required(:direct_product_implication) => String.t() | nil,
          required(:formula) => map(),
          required(:provenance_reference) => map(),
          required(:scores) => map()
        }

  @type quarantine_summary :: %{
          required(:id) => String.t(),
          required(:reason_codes) => [atom()],
          required(:candidate_record_ids) => [String.t()],
          required(:raw_record_ids) => [String.t()]
        }

  @type t :: %__MODULE__{
          snapshot_id: String.t(),
          snapshot_label: String.t() | nil,
          snapshot_finalized_at: DateTime.t(),
          profile_id: String.t(),
          digest: String.t(),
          normalized_theme_ids: [String.t()],
          branch_ids: [String.t()],
          retrieval_run_ids: [String.t()],
          accepted_core: [packaged_record()],
          accepted_analog: [packaged_record()],
          background: [packaged_record()],
          quarantine_summary: [quarantine_summary()],
          citation_keys: [CitationKey.t()],
          provenance_references: %{optional(String.t()) => map()},
          excluded_inputs: [String.t()]
        }
end
