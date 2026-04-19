defmodule ResearchStore.Artifacts.CorpusSnapshot do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "corpus_snapshots" do
    field(:label, :string)
    field(:finalized_at, :utc_datetime_usec)
    field(:normalized_theme_ids, {:array, :string}, default: [])
    field(:branch_ids, {:array, :string}, default: [])
    field(:retrieval_run_ids, {:array, :string}, default: [])
    field(:duplicate_group_ids, {:array, :string}, default: [])
    field(:accepted_core_count, :integer, default: 0)
    field(:accepted_analog_count, :integer, default: 0)
    field(:background_count, :integer, default: 0)
    field(:quarantine_count, :integer, default: 0)
    field(:discard_count, :integer, default: 0)
    field(:qa_summary, :map, default: %{})
    field(:duplicate_summary, :map, default: %{})
    field(:quarantine_summary, :map, default: %{})
    field(:discard_summary, :map, default: %{})
    field(:source_lineage, :map, default: %{})

    has_many(:snapshot_records, ResearchStore.Artifacts.CorpusSnapshotRecord)
    has_many(:snapshot_quarantines, ResearchStore.Artifacts.CorpusSnapshotQuarantine)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :id,
      :label,
      :finalized_at,
      :normalized_theme_ids,
      :branch_ids,
      :retrieval_run_ids,
      :duplicate_group_ids,
      :accepted_core_count,
      :accepted_analog_count,
      :background_count,
      :quarantine_count,
      :discard_count,
      :qa_summary,
      :duplicate_summary,
      :quarantine_summary,
      :discard_summary,
      :source_lineage
    ])
    |> validate_required([:id, :finalized_at])
    |> validate_number(:accepted_core_count, greater_than_or_equal_to: 0)
    |> validate_number(:accepted_analog_count, greater_than_or_equal_to: 0)
    |> validate_number(:background_count, greater_than_or_equal_to: 0)
    |> validate_number(:quarantine_count, greater_than_or_equal_to: 0)
    |> validate_number(:discard_count, greater_than_or_equal_to: 0)
  end
end
