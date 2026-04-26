defmodule ResearchCore.Evidence.GrobidTeiParserTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Evidence.{BoundingBox, EvidenceSpan, FormulaBlock, GrobidTeiParser}

  test "parses GROBID TEI formula nodes into evidence-backed formula blocks" do
    tei = """
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader>
        <fileDesc>
          <titleStmt>
            <title>Calibration Under Stress</title>
          </titleStmt>
        </fileDesc>
      </teiHeader>
      <text>
        <body>
          <div>
            <head>Model</head>
            <p coords="1,10.0,20.0,200.0,20.0">
              We define the score as
              <formula xml:id="formula_1" coords="2,10.5,20.25,150.0,12.0">score = wins / total</formula>.
            </p>
          </div>
        </body>
      </text>
    </TEI>
    """

    assert {:ok, result} =
             GrobidTeiParser.parse(tei,
               document_id: "doc-1",
               source_uri: "https://arxiv.org/pdf/2401.12345.pdf",
               parser_version: "0.8.x"
             )

    assert result.parser == :grobid
    assert result.document.id == "doc-1"
    assert result.document.title == "Calibration Under Stress"
    assert result.document.source_uri == "https://arxiv.org/pdf/2401.12345.pdf"
    assert [%{page_number: 2}] = result.pages

    assert [
             %FormulaBlock{
               document_id: "doc-1",
               label: "formula_1",
               raw_text: "score = wins / total",
               normalized_text: "score = wins / total",
               source: :grobid,
               page_numbers: [2],
               bboxes: [%BoundingBox{page: 2, x: 10.5, y: 20.25, width: 150.0, height: 12.0}],
               ambiguity_markers: []
             }
           ] = result.formula_blocks

    assert [
             %EvidenceSpan{
               document_id: "doc-1",
               page_number: 2,
               quote_text: "score = wins / total",
               source: :grobid,
               bboxes: [%BoundingBox{page: 2}]
             }
           ] = result.evidence_spans
  end

  test "marks formula blocks without coordinates as ambiguous" do
    tei = """
    <TEI>
      <text>
        <body>
          <formula n="eq-1">edge = payoff / variance</formula>
        </body>
      </text>
    </TEI>
    """

    assert {:ok, result} = GrobidTeiParser.parse(tei, document_id: "doc-2")

    assert [%FormulaBlock{label: "eq-1", page_numbers: [], bboxes: [], confidence: 0.65}] =
             result.formula_blocks

    assert [:missing_coordinates] = hd(result.formula_blocks).ambiguity_markers
    assert result.pages == []
  end

  test "returns parse errors for invalid TEI" do
    assert {:error, {:invalid_tei_xml, _reason}} = GrobidTeiParser.parse("<TEI><broken>")
  end
end
