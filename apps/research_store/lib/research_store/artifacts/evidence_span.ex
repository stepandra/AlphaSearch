defmodule ResearchStore.Artifacts.EvidenceSpan do
  use Ecto.Schema

  import Ecto.Changeset

  @source_values ~w(grobid marker nougat pdf_text ocr manual)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "evidence_spans" do
    field(:page_number, :integer)
    field(:quote_text, :string)
    field(:quote_hash, :string)
    field(:source, :string)
    field(:source_ref, :string)
    field(:bboxes, {:array, :map}, default: [])
    field(:metadata, :map, default: %{})

    belongs_to(:evidence_document, ResearchStore.Artifacts.EvidenceDocument, type: :string)
    has_many(:formula_blocks, ResearchStore.Artifacts.EvidenceFormulaBlock)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(span, attrs) do
    span
    |> cast(attrs, [
      :id,
      :evidence_document_id,
      :page_number,
      :quote_text,
      :quote_hash,
      :source,
      :source_ref,
      :bboxes,
      :metadata
    ])
    |> validate_required([:id, :evidence_document_id, :quote_text, :quote_hash, :source])
    |> validate_number(:page_number, greater_than: 0)
    |> validate_inclusion(:source, @source_values)
    |> foreign_key_constraint(:evidence_document_id)
  end
end
