defmodule ResearchCore.Evidence.EvidenceSpan do
  @moduledoc """
  Exact evidence span extracted from a source document.
  """

  alias ResearchCore.Evidence.BoundingBox

  @enforce_keys [:id, :document_id, :quote_text, :quote_hash, :source]
  defstruct [
    :id,
    :document_id,
    :page_number,
    :quote_text,
    :quote_hash,
    :source,
    :source_ref,
    bboxes: [],
    metadata: %{}
  ]

  @type source :: :grobid | :marker | :nougat | :pdf_text | :ocr | :manual

  @type t :: %__MODULE__{
          id: String.t(),
          document_id: String.t(),
          page_number: pos_integer() | nil,
          quote_text: String.t(),
          quote_hash: String.t(),
          source: source(),
          source_ref: String.t() | nil,
          bboxes: [BoundingBox.t()],
          metadata: map()
        }
end
