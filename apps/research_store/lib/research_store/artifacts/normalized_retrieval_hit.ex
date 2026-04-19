defmodule ResearchStore.Artifacts.NormalizedRetrievalHit do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "normalized_retrieval_hits" do
    field(:provider, :string)
    field(:rank, :integer)
    field(:title, :string)
    field(:url, :string)
    field(:snippet, :string)
    field(:raw_payload, :map)
    field(:fetch_status, :string)

    belongs_to(:retrieval_run, ResearchStore.Artifacts.RetrievalRun, type: :string)

    belongs_to(:search_request, ResearchStore.Artifacts.SearchRequest, type: :string)

    belongs_to(:generated_query, ResearchStore.Artifacts.GeneratedQuery, type: :string)

    belongs_to(:fetched_document, ResearchStore.Artifacts.FetchedDocument, type: :string)

    has_many(:raw_corpus_records, ResearchStore.Artifacts.RawCorpusRecord,
      foreign_key: :search_hit_id
    )

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(hit, attrs) do
    hit
    |> cast(attrs, [
      :id,
      :retrieval_run_id,
      :search_request_id,
      :generated_query_id,
      :fetched_document_id,
      :provider,
      :rank,
      :title,
      :url,
      :snippet,
      :raw_payload,
      :fetch_status
    ])
    |> validate_required([
      :id,
      :retrieval_run_id,
      :search_request_id,
      :generated_query_id,
      :provider,
      :rank,
      :title,
      :url
    ])
    |> validate_number(:rank, greater_than: 0)
    |> foreign_key_constraint(:retrieval_run_id)
    |> foreign_key_constraint(:search_request_id)
    |> foreign_key_constraint(:generated_query_id)
    |> foreign_key_constraint(:fetched_document_id)
  end
end
