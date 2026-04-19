defmodule ResearchStore.Artifacts.FetchedDocument do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "fetched_documents" do
    field(:url, :string)
    field(:content, :string)
    field(:content_format, :string)
    field(:title, :string)
    field(:raw_payload, :map)
    field(:fetched_at, :utc_datetime_usec)
    field(:content_fingerprint, :string)

    has_many(:retrieval_hits, ResearchStore.Artifacts.NormalizedRetrievalHit)
    has_many(:raw_corpus_records, ResearchStore.Artifacts.RawCorpusRecord)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :id,
      :url,
      :content,
      :content_format,
      :title,
      :raw_payload,
      :fetched_at,
      :content_fingerprint
    ])
    |> validate_required([:id, :url, :content, :content_format, :content_fingerprint])
    |> unique_constraint(:url)
    |> unique_constraint(:content_fingerprint)
  end
end
