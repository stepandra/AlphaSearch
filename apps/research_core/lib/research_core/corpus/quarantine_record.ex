defmodule ResearchCore.Corpus.QuarantineRecord do
  @moduledoc """
  Record held back from downstream synthesis because it needs manual review.
  """

  alias ResearchCore.Corpus.{AcceptanceDecision, CanonicalRecord}

  @enforce_keys [:id, :raw_record_ids, :reason_codes, :decision]
  defstruct [
    :id,
    :decision,
    :canonical_record,
    raw_record_ids: [],
    reason_codes: [],
    candidate_records: [],
    details: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          raw_record_ids: [String.t()],
          reason_codes: [atom()],
          decision: AcceptanceDecision.t(),
          canonical_record: CanonicalRecord.t() | nil,
          candidate_records: [CanonicalRecord.t()],
          details: map()
        }
end
