defmodule ResearchCore.Strategy.InputPackage do
  @moduledoc """
  Deterministic extraction payload derived from a finalized snapshot plus a validated synthesis artifact.
  """

  alias ResearchCore.Strategy.Section

  @enforce_keys [
    :corpus_snapshot_id,
    :snapshot_finalized_at,
    :synthesis_run_id,
    :synthesis_artifact_id,
    :synthesis_profile_id,
    :report_sections,
    :resolved_records,
    :digest
  ]
  defstruct [
    :corpus_snapshot_id,
    :snapshot_label,
    :snapshot_finalized_at,
    :synthesis_run_id,
    :synthesis_artifact_id,
    :synthesis_profile_id,
    :artifact_hash,
    :artifact_finalized_at,
    :branch_context,
    :theme_context,
    :digest,
    normalized_theme_ids: [],
    branch_ids: [],
    report_sections: [],
    section_lookup: %{},
    resolved_records: %{},
    cited_record_keys: [],
    snapshot_metadata: %{},
    record_formula_availability: %{},
    provenance_summaries: %{}
  ]

  @type resolved_record :: %{
          required(:record_id) => String.t(),
          required(:classification) => atom(),
          required(:citation_key) => String.t(),
          required(:title) => String.t() | nil,
          required(:formula) => map(),
          required(:provenance_reference) => map(),
          optional(atom()) => term()
        }

  @type t :: %__MODULE__{
          corpus_snapshot_id: String.t(),
          snapshot_label: String.t() | nil,
          snapshot_finalized_at: DateTime.t(),
          synthesis_run_id: String.t(),
          synthesis_artifact_id: String.t(),
          synthesis_profile_id: String.t(),
          artifact_hash: String.t() | nil,
          artifact_finalized_at: DateTime.t() | nil,
          normalized_theme_ids: [String.t()],
          branch_ids: [String.t()],
          report_sections: [Section.t()],
          section_lookup: %{optional(atom()) => Section.t()},
          resolved_records: %{optional(String.t()) => resolved_record()},
          cited_record_keys: [String.t()],
          snapshot_metadata: map(),
          record_formula_availability: %{optional(String.t()) => map()},
          provenance_summaries: %{optional(String.t()) => map()},
          branch_context: map() | nil,
          theme_context: map() | nil,
          digest: String.t()
        }
end
