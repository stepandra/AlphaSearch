defmodule ResearchStore.Artifacts.EvidenceFormulaBlock do
  use Ecto.Schema

  import Ecto.Changeset

  @source_values ~w(grobid marker nougat pdf_text ocr llm_extracted)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "evidence_formula_blocks" do
    field(:label, :string)
    field(:raw_text, :string)
    field(:normalized_text, :string)
    field(:latex, :string)
    field(:source, :string)
    field(:source_ref, :string)
    field(:page_numbers, {:array, :integer}, default: [])
    field(:bboxes, {:array, :map}, default: [])
    field(:confidence, :float)
    field(:parser, :string)
    field(:metadata, :map, default: %{})
    field(:ambiguity_markers, {:array, :string}, default: [])

    belongs_to(:evidence_document, ResearchStore.Artifacts.EvidenceDocument, type: :string)
    belongs_to(:evidence_span, ResearchStore.Artifacts.EvidenceSpan, type: :string)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(formula_block, attrs) do
    formula_block
    |> cast(attrs, [
      :id,
      :evidence_document_id,
      :evidence_span_id,
      :label,
      :raw_text,
      :normalized_text,
      :latex,
      :source,
      :source_ref,
      :page_numbers,
      :bboxes,
      :confidence,
      :parser,
      :metadata,
      :ambiguity_markers
    ])
    |> validate_required([:id, :evidence_document_id, :raw_text, :source])
    |> validate_inclusion(:source, @source_values)
    |> foreign_key_constraint(:evidence_document_id)
    |> foreign_key_constraint(:evidence_span_id)
  end
end
