defmodule ResearchStore.Artifacts.CorpusSnapshotRecord do
  use Ecto.Schema

  import Ecto.Changeset

  @classification_values ~w(accepted_core accepted_analog background)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "corpus_snapshot_records" do
    field(:classification, :string)
    field(:inclusion_reason, :map, default: %{})

    belongs_to(:corpus_snapshot, ResearchStore.Artifacts.CorpusSnapshot, type: :string)

    belongs_to(:canonical_record, ResearchStore.Artifacts.CanonicalCorpusRecord,
      foreign_key: :canonical_record_id,
      type: :string
    )

    belongs_to(:qa_decision, ResearchStore.Artifacts.QADecision, type: :string)

    belongs_to(:duplicate_group, ResearchStore.Artifacts.DuplicateGroup, type: :string)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :id,
      :corpus_snapshot_id,
      :canonical_record_id,
      :qa_decision_id,
      :duplicate_group_id,
      :classification,
      :inclusion_reason
    ])
    |> validate_required([:id, :corpus_snapshot_id, :canonical_record_id, :classification])
    |> validate_inclusion(:classification, @classification_values)
    |> foreign_key_constraint(:corpus_snapshot_id)
    |> foreign_key_constraint(:canonical_record_id)
    |> foreign_key_constraint(:qa_decision_id)
    |> foreign_key_constraint(:duplicate_group_id)
    |> unique_constraint([:corpus_snapshot_id, :canonical_record_id, :classification])
  end
end
