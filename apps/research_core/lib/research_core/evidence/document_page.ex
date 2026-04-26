defmodule ResearchCore.Evidence.DocumentPage do
  @moduledoc """
  Page observed in parser output.

  Text is optional because parsers such as GROBID may provide coordinates for
  blocks without a trustworthy full-page text reconstruction.
  """

  @enforce_keys [:id, :document_id, :page_number]
  defstruct [
    :id,
    :document_id,
    :page_number,
    :text,
    :text_hash,
    source: :parser_coordinates,
    metadata: %{}
  ]

  @type source :: :parser_coordinates | :pdf_text | :ocr | :latex_source

  @type t :: %__MODULE__{
          id: String.t(),
          document_id: String.t(),
          page_number: pos_integer(),
          text: String.t() | nil,
          text_hash: String.t() | nil,
          source: source(),
          metadata: map()
        }
end
