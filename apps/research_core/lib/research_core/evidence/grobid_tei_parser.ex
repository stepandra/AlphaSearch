defmodule ResearchCore.Evidence.GrobidTeiParser do
  @moduledoc """
  Parses GROBID TEI XML into evidence-first document artifacts.

  The parser intentionally treats formulas as parser observations, not as
  verified FormulaIR. Downstream normalization must still parse variables,
  units, assumptions, and mathematical structure.
  """

  require Record

  alias ResearchCore.Canonical

  alias ResearchCore.Evidence.{
    BoundingBox,
    Document,
    DocumentPage,
    EvidenceSpan,
    FormulaBlock,
    ParserResult
  }

  Record.defrecordp(:xmlElement, Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl"))

  Record.defrecordp(
    :xmlAttribute,
    Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecordp(:xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  @parser :grobid

  @type parse_option ::
          {:document_id, String.t()}
          | {:source_uri, String.t()}
          | {:content_hash, String.t()}
          | {:parser_version, String.t()}
          | {:mime_type, String.t()}

  @spec parse(String.t(), [parse_option()]) :: {:ok, ParserResult.t()} | {:error, term()}
  def parse(tei_xml, opts \\ [])

  def parse(tei_xml, opts) when is_binary(tei_xml) do
    with {:ok, document_tree} <- parse_xml(tei_xml) do
      document = build_document(document_tree, tei_xml, opts)
      formula_nodes = xpath(~c"//formula", document_tree)

      {formula_blocks, evidence_spans, warnings} =
        formula_nodes
        |> Enum.with_index(1)
        |> Enum.reduce({[], [], []}, fn {node, index}, {formulas, spans, warnings} ->
          case formula_artifacts(document, node, index) do
            {:ok, formula, span, formula_warnings} ->
              {[formula | formulas], [span | spans], formula_warnings ++ warnings}

            {:skip, warning} ->
              {formulas, spans, [warning | warnings]}
          end
        end)

      pages = build_pages(document.id, formula_blocks)

      {:ok,
       %ParserResult{
         document: document,
         parser: @parser,
         parser_version: Keyword.get(opts, :parser_version),
         pages: pages,
         evidence_spans: Enum.reverse(evidence_spans),
         formula_blocks: Enum.reverse(formula_blocks),
         raw_artifact: tei_xml,
         warnings: Enum.reverse(warnings),
         metadata: %{formula_count: length(formula_blocks)}
       }}
    end
  end

  def parse(_tei_xml, _opts), do: {:error, :invalid_tei_xml}

  defp parse_xml(tei_xml) do
    try do
      {document_tree, _rest} =
        tei_xml
        |> String.to_charlist()
        |> :xmerl_scan.string(quiet: true)

      {:ok, document_tree}
    catch
      :exit, reason -> {:error, {:invalid_tei_xml, reason}}
    end
  end

  defp build_document(document_tree, tei_xml, opts) do
    content_hash = Keyword.get(opts, :content_hash) || Canonical.hash(tei_xml)
    document_id = Keyword.get(opts, :document_id) || id("document", content_hash)

    %Document{
      id: document_id,
      source_uri: Keyword.get(opts, :source_uri),
      content_hash: content_hash,
      mime_type: Keyword.get(opts, :mime_type, "application/tei+xml"),
      title: title(document_tree),
      parser: @parser,
      parser_version: Keyword.get(opts, :parser_version),
      metadata: %{}
    }
  end

  defp formula_artifacts(%Document{} = document, node, index) do
    raw_text = node |> text_content() |> normalize_text()
    label = attr(node, :"xml:id") || attr(node, :id) || attr(node, :n)
    bboxes = node |> attr(:coords) |> parse_coords()
    page_numbers = bboxes |> Enum.map(& &1.page) |> Enum.uniq() |> Enum.sort()

    cond do
      raw_text == "" ->
        {:skip,
         %{
           type: :empty_formula_node,
           source_ref: label || "formula:#{index}",
           message: "GROBID formula node did not contain text"
         }}

      true ->
        source_ref = label || "formula:#{index}"

        span_id =
          id("evidence_span", %{document_id: document.id, source_ref: source_ref, text: raw_text})

        span = %EvidenceSpan{
          id: span_id,
          document_id: document.id,
          page_number: List.first(page_numbers),
          quote_text: raw_text,
          quote_hash: Canonical.hash(raw_text),
          source: @parser,
          source_ref: source_ref,
          bboxes: bboxes,
          metadata: %{tei_element: "formula"}
        }

        formula = %FormulaBlock{
          id:
            id("formula_block", %{
              document_id: document.id,
              source_ref: source_ref,
              text: raw_text
            }),
          document_id: document.id,
          label: label,
          raw_text: raw_text,
          normalized_text: canonical_formula_text(raw_text),
          source: @parser,
          source_ref: source_ref,
          evidence_span_id: span_id,
          page_numbers: page_numbers,
          bboxes: bboxes,
          confidence: confidence(bboxes),
          parser: @parser,
          metadata: %{tei_element: "formula"},
          ambiguity_markers: ambiguity_markers(bboxes)
        }

        {:ok, formula, span, []}
    end
  end

  defp title(document_tree) do
    document_tree
    |> xpath_string(~c"//teiHeader//titleStmt/title")
    |> List.first()
    |> case do
      nil -> nil
      title_node -> title_node |> text_content() |> normalize_text() |> blank_to_nil()
    end
  end

  defp build_pages(document_id, formula_blocks) do
    formula_blocks
    |> Enum.flat_map(& &1.page_numbers)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn page_number ->
      %DocumentPage{
        id: id("document_page", %{document_id: document_id, page_number: page_number}),
        document_id: document_id,
        page_number: page_number,
        source: :parser_coordinates,
        metadata: %{parser: @parser}
      }
    end)
  end

  defp xpath(path, document_tree), do: :xmerl_xpath.string(path, document_tree)
  defp xpath_string(document_tree, path), do: xpath(path, document_tree)

  defp attr(node, name) do
    node
    |> xmlElement(:attributes)
    |> Enum.find(fn attribute -> xmlAttribute(attribute, :name) == name end)
    |> case do
      nil -> nil
      attribute -> attribute |> xmlAttribute(:value) |> to_string() |> blank_to_nil()
    end
  end

  defp text_content(xmlText(value: value)), do: to_string(value)

  defp text_content(xmlElement(content: content)) do
    content
    |> Enum.map(&text_content/1)
    |> Enum.join(" ")
  end

  defp text_content(_other), do: ""

  defp parse_coords(nil), do: []

  defp parse_coords(coords) do
    coords
    |> String.split(";", trim: true)
    |> Enum.flat_map(&parse_coord_box/1)
  end

  defp parse_coord_box(coord_box) do
    case String.split(coord_box, ",", trim: true) do
      [page, x, y, width, height] ->
        with {page, ""} <- Integer.parse(String.trim(page)),
             {x, ""} <- Float.parse(String.trim(x)),
             {y, ""} <- Float.parse(String.trim(y)),
             {width, ""} <- Float.parse(String.trim(width)),
             {height, ""} <- Float.parse(String.trim(height)),
             true <- page > 0 do
          [%BoundingBox{page: page, x: x, y: y, width: width, height: height}]
        else
          _invalid -> []
        end

      _invalid ->
        []
    end
  end

  defp confidence([]), do: 0.65
  defp confidence(_bboxes), do: 0.85

  defp ambiguity_markers([]), do: [:missing_coordinates]
  defp ambiguity_markers(_bboxes), do: []

  defp canonical_formula_text(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp normalize_text(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp id(prefix, value), do: prefix <> "_" <> (Canonical.hash(value) |> binary_part(0, 24))
end
