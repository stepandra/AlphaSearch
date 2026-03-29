defmodule ResearchCore.Corpus.AcceptanceDecision do
  @moduledoc """
  One machine-readable QA decision captured in the audit trail.
  """

  alias ResearchCore.Corpus.RecordClassification

  @enforce_keys [:record_id, :stage, :action]
  defstruct [
    :record_id,
    :canonical_record_id,
    :stage,
    :action,
    :classification,
    reason_codes: [],
    score_snapshot: %{},
    details: %{},
    duplicate_group_id: nil
  ]

  @type stage :: :conflation_detection | :duplicate_grouping | :classification
  @type action :: :accepted | :downgraded | :quarantined | :discarded | :merged | :split

  @type t :: %__MODULE__{
          record_id: String.t(),
          canonical_record_id: String.t() | nil,
          stage: stage(),
          action: action(),
          classification: RecordClassification.t() | nil,
          reason_codes: [atom()],
          score_snapshot: map(),
          details: map(),
          duplicate_group_id: String.t() | nil
        }
end
