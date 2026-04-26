defmodule ResearchStore.EvidenceArtifactsTest do
  use ExUnit.Case, async: true

  alias ResearchStore.Artifacts.{
    EvidenceDocument,
    EvidenceDocumentPage,
    EvidenceFormulaBlock,
    EvidenceSpan
  }

  test "evidence document requires stable identity and content hash" do
    changeset =
      EvidenceDocument.changeset(%EvidenceDocument{}, %{
        id: "document_1",
        content_hash: "hash-1",
        source_uri: "https://arxiv.org/pdf/2401.12345.pdf",
        parser: "grobid"
      })

    assert changeset.valid?
  end

  test "evidence document page validates positive page number and source" do
    valid =
      EvidenceDocumentPage.changeset(%EvidenceDocumentPage{}, %{
        id: "page-1",
        evidence_document_id: "document_1",
        page_number: 1,
        source: "parser_coordinates"
      })

    invalid =
      EvidenceDocumentPage.changeset(%EvidenceDocumentPage{}, %{
        id: "page-0",
        evidence_document_id: "document_1",
        page_number: 0,
        source: "unknown"
      })

    assert valid.valid?
    refute invalid.valid?
  end

  test "evidence span captures exact quote and parser provenance" do
    changeset =
      EvidenceSpan.changeset(%EvidenceSpan{}, %{
        id: "span-1",
        evidence_document_id: "document_1",
        page_number: 2,
        quote_text: "score = wins / total",
        quote_hash: "quote-hash",
        source: "grobid",
        source_ref: "formula_1",
        bboxes: [%{page: 2, x: 10.5, y: 20.25, width: 150.0, height: 12.0}]
      })

    assert changeset.valid?
  end

  test "formula block stores parser observation without requiring FormulaIR" do
    changeset =
      EvidenceFormulaBlock.changeset(%EvidenceFormulaBlock{}, %{
        id: "formula-block-1",
        evidence_document_id: "document_1",
        evidence_span_id: "span-1",
        raw_text: "score = wins / total",
        normalized_text: "score = wins / total",
        source: "grobid",
        parser: "grobid",
        page_numbers: [2],
        ambiguity_markers: []
      })

    assert changeset.valid?
  end
end
