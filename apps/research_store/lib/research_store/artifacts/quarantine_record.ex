defmodule ResearchStore.Artifacts.QuarantineRecord do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "quarantine_records" do
    field(:raw_record_ids, {:array, :string}, default: [])
    field(:reason_codes, {:array, :string}, default: [])
    field(:candidate_record_ids, {:array, :string}, default: [])
    field(:details, :map, default: %{})

    belongs_to(:decision, ResearchStore.Artifacts.QADecision, type: :string)

    belongs_to(:canonical_record, ResearchStore.Artifacts.CanonicalCorpusRecord, type: :string)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :id,
      :decision_id,
      :canonical_record_id,
      :raw_record_ids,
      :reason_codes,
      :candidate_record_ids,
      :details
    ])
    |> validate_required([:id, :decision_id, :raw_record_ids, :reason_codes])
    |> foreign_key_constraint(:decision_id)
    |> foreign_key_constraint(:canonical_record_id)
  end
end
