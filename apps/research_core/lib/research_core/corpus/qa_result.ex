defmodule ResearchCore.Corpus.QAResult do
  @moduledoc """
  Deterministic outputs emitted by the corpus QA pipeline.
  """

  alias ResearchCore.Corpus.{
    AcceptanceDecision,
    CanonicalRecord,
    DuplicateGroup,
    QuarantineRecord
  }

  defstruct accepted_core: [],
            accepted_analog: [],
            background: [],
            quarantine: [],
            discard_log: [],
            duplicate_groups: [],
            qa_decision_summary: %{},
            decision_log: []

  @type t :: %__MODULE__{
          accepted_core: [CanonicalRecord.t()],
          accepted_analog: [CanonicalRecord.t()],
          background: [CanonicalRecord.t()],
          quarantine: [QuarantineRecord.t()],
          discard_log: [AcceptanceDecision.t()],
          duplicate_groups: [DuplicateGroup.t()],
          qa_decision_summary: map(),
          decision_log: [AcceptanceDecision.t()]
        }
end
