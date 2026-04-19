defmodule ResearchStore.Artifacts.QADecision do
  use Ecto.Schema

  import Ecto.Changeset

  alias ResearchCore.Corpus.RecordClassification

  @stage_values ~w(conflation_detection duplicate_grouping classification)
  @action_values ~w(accepted downgraded quarantined discarded merged split)
  @classification_values Enum.map(RecordClassification.all(), &Atom.to_string/1)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "qa_decisions" do
    field(:record_id, :string)
    field(:stage, :string)
    field(:action, :string)
    field(:classification, :string)
    field(:reason_codes, {:array, :string}, default: [])
    field(:score_snapshot, :map, default: %{})
    field(:details, :map, default: %{})
    field(:duplicate_group_id, :string)

    belongs_to(:canonical_record, ResearchStore.Artifacts.CanonicalCorpusRecord,
      foreign_key: :canonical_record_id,
      type: :string
    )

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(decision, attrs) do
    decision
    |> cast(attrs, [
      :id,
      :record_id,
      :canonical_record_id,
      :stage,
      :action,
      :classification,
      :reason_codes,
      :score_snapshot,
      :details,
      :duplicate_group_id
    ])
    |> validate_required([:id, :record_id, :stage, :action])
    |> validate_inclusion(:stage, @stage_values)
    |> validate_inclusion(:action, @action_values)
    |> validate_inclusion(:classification, @classification_values)
    |> foreign_key_constraint(:canonical_record_id)
    |> foreign_key_constraint(:duplicate_group_id)
  end
end
