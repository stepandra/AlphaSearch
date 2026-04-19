defmodule ResearchStore.Artifacts.DuplicateGroup do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "duplicate_groups" do
    field(:representative_record_id, :string)
    field(:member_record_ids, {:array, :string}, default: [])
    field(:member_raw_record_ids, {:array, :string}, default: [])
    field(:match_reasons, {:array, :map}, default: [])
    field(:merge_strategy, :string)

    belongs_to(:canonical_record, ResearchStore.Artifacts.CanonicalCorpusRecord,
      foreign_key: :canonical_record_id,
      type: :string
    )

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(group, attrs) do
    group
    |> cast(attrs, [
      :id,
      :canonical_record_id,
      :representative_record_id,
      :member_record_ids,
      :member_raw_record_ids,
      :match_reasons,
      :merge_strategy
    ])
    |> validate_required([
      :id,
      :canonical_record_id,
      :representative_record_id,
      :member_record_ids,
      :merge_strategy
    ])
    |> foreign_key_constraint(:canonical_record_id)
  end
end
