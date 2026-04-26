defmodule ResearchCore.Evidence.ParserResult do
  @moduledoc """
  Normalized output from a source-document parser.
  """

  alias ResearchCore.Evidence.{Document, DocumentPage, EvidenceSpan, FormulaBlock}

  @enforce_keys [:document, :parser]
  defstruct [
    :document,
    :parser,
    parser_version: nil,
    pages: [],
    evidence_spans: [],
    formula_blocks: [],
    raw_artifact: nil,
    warnings: [],
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          document: Document.t(),
          parser: atom(),
          parser_version: String.t() | nil,
          pages: [DocumentPage.t()],
          evidence_spans: [EvidenceSpan.t()],
          formula_blocks: [FormulaBlock.t()],
          raw_artifact: term(),
          warnings: [map()],
          metadata: map()
        }
end
