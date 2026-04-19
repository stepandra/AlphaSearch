defmodule ResearchStore.Artifacts.RawCorpusRecord do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "raw_corpus_records" do
    field(:raw_fields, :map, default: %{})

    belongs_to(:search_hit, ResearchStore.Artifacts.NormalizedRetrievalHit, type: :string)

    belongs_to(:fetched_document, ResearchStore.Artifacts.FetchedDocument, type: :string)

    belongs_to(:retrieval_run, ResearchStore.Artifacts.RetrievalRun, type: :string)

    belongs_to(:research_branch, ResearchStore.Artifacts.ResearchBranch, type: :string)

    belongs_to(:normalized_theme, ResearchStore.Artifacts.NormalizedTheme, type: :string)

    belongs_to(:split_from, ResearchStore.Artifacts.RawCorpusRecord,
      foreign_key: :split_from_id,
      type: :string
    )

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :id,
      :search_hit_id,
      :fetched_document_id,
      :retrieval_run_id,
      :research_branch_id,
      :normalized_theme_id,
      :split_from_id,
      :raw_fields
    ])
    |> validate_required([:id, :search_hit_id])
    |> foreign_key_constraint(:search_hit_id)
    |> foreign_key_constraint(:fetched_document_id)
    |> foreign_key_constraint(:retrieval_run_id)
    |> foreign_key_constraint(:research_branch_id)
    |> foreign_key_constraint(:normalized_theme_id)
    |> foreign_key_constraint(:split_from_id)
  end
end
