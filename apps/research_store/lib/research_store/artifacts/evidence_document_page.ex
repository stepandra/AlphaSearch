defmodule ResearchStore.Artifacts.EvidenceDocumentPage do
  use Ecto.Schema

  import Ecto.Changeset

  @source_values ~w(parser_coordinates pdf_text ocr latex_source)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "evidence_document_pages" do
    field(:page_number, :integer)
    field(:text, :string)
    field(:text_hash, :string)
    field(:source, :string)
    field(:metadata, :map, default: %{})

    belongs_to(:evidence_document, ResearchStore.Artifacts.EvidenceDocument, type: :string)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(page, attrs) do
    page
    |> cast(attrs, [
      :id,
      :evidence_document_id,
      :page_number,
      :text,
      :text_hash,
      :source,
      :metadata
    ])
    |> validate_required([:id, :evidence_document_id, :page_number, :source])
    |> validate_number(:page_number, greater_than: 0)
    |> validate_inclusion(:source, @source_values)
    |> foreign_key_constraint(:evidence_document_id)
    |> unique_constraint([:evidence_document_id, :page_number])
  end
end
