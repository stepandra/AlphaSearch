defmodule ResearchStore.Artifacts.EvidenceDocument do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "evidence_documents" do
    field(:source_uri, :string)
    field(:content_hash, :string)
    field(:mime_type, :string)
    field(:title, :string)
    field(:parser, :string)
    field(:parser_version, :string)
    field(:metadata, :map, default: %{})

    has_many(:pages, ResearchStore.Artifacts.EvidenceDocumentPage)
    has_many(:evidence_spans, ResearchStore.Artifacts.EvidenceSpan)
    has_many(:formula_blocks, ResearchStore.Artifacts.EvidenceFormulaBlock)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :id,
      :source_uri,
      :content_hash,
      :mime_type,
      :title,
      :parser,
      :parser_version,
      :metadata
    ])
    |> validate_required([:id, :content_hash])
    |> unique_constraint(:content_hash)
  end
end
