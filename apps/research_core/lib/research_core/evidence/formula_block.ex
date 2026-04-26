defmodule ResearchCore.Evidence.FormulaBlock do
  @moduledoc """
  Parser-observed formula or equation block.

  This is not a canonical formula. It is an evidence-backed candidate that can
  later be normalized into FormulaIR.
  """

  alias ResearchCore.Evidence.BoundingBox

  @enforce_keys [:id, :document_id, :raw_text, :source]
  defstruct [
    :id,
    :document_id,
    :label,
    :raw_text,
    :normalized_text,
    :latex,
    :source,
    :source_ref,
    :evidence_span_id,
    page_numbers: [],
    bboxes: [],
    confidence: nil,
    parser: nil,
    metadata: %{},
    ambiguity_markers: []
  ]

  @type source :: :grobid | :marker | :nougat | :pdf_text | :ocr | :llm_extracted

  @type t :: %__MODULE__{
          id: String.t(),
          document_id: String.t(),
          label: String.t() | nil,
          raw_text: String.t(),
          normalized_text: String.t() | nil,
          latex: String.t() | nil,
          source: source(),
          source_ref: String.t() | nil,
          evidence_span_id: String.t() | nil,
          page_numbers: [pos_integer()],
          bboxes: [BoundingBox.t()],
          confidence: float() | nil,
          parser: atom() | nil,
          metadata: map(),
          ambiguity_markers: [atom()]
        }
end
