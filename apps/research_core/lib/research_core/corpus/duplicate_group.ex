defmodule ResearchCore.Corpus.DuplicateGroup do
  @moduledoc """
  Inspectable grouping of raw and canonical records that collapsed together.
  """

  alias ResearchCore.Corpus.AcceptanceDecision

  @enforce_keys [:id, :member_record_ids, :canonical_record_id, :representative_record_id]
  defstruct [
    :id,
    :canonical_record_id,
    :representative_record_id,
    member_record_ids: [],
    member_raw_record_ids: [],
    match_reasons: [],
    merge_strategy: :representative_plus_field_fill,
    decisions: []
  ]

  @type match_reason :: %{
          required(:rule) => atom(),
          optional(atom()) => term()
        }

  @type t :: %__MODULE__{
          id: String.t(),
          canonical_record_id: String.t(),
          representative_record_id: String.t(),
          member_record_ids: [String.t()],
          member_raw_record_ids: [String.t()],
          match_reasons: [match_reason()],
          merge_strategy: :representative_plus_field_fill,
          decisions: [AcceptanceDecision.t()]
        }
end
