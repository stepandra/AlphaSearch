defmodule ResearchStore.Artifacts.CorpusSnapshotQuarantine do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "corpus_snapshot_quarantines" do
    field(:reason_codes, {:array, :string}, default: [])

    belongs_to(:corpus_snapshot, ResearchStore.Artifacts.CorpusSnapshot, type: :string)

    belongs_to(:quarantine_record, ResearchStore.Artifacts.QuarantineRecord, type: :string)

    belongs_to(:qa_decision, ResearchStore.Artifacts.QADecision, type: :string)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :id,
      :corpus_snapshot_id,
      :quarantine_record_id,
      :qa_decision_id,
      :reason_codes
    ])
    |> validate_required([:id, :corpus_snapshot_id, :quarantine_record_id])
    |> foreign_key_constraint(:corpus_snapshot_id)
    |> foreign_key_constraint(:quarantine_record_id)
    |> foreign_key_constraint(:qa_decision_id)
    |> unique_constraint([:corpus_snapshot_id, :quarantine_record_id])
  end
end
