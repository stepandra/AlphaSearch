defmodule ResearchJobs.Corpus.RawRecordBuilder do
  @moduledoc """
  Deterministically converts retrieval outputs into raw corpus records.

  The builder stays intentionally lightweight: it preserves query, branch,
  fetch-document, and theme provenance without hiding the intermediate shape
  behind persistence or additional extraction passes.
  """

  alias ResearchCore.Branch.Branch
  alias ResearchCore.Corpus.RawRecord
  alias ResearchCore.Retrieval.{FetchResult, NormalizedSearchHit, RetrievalRun}
  alias ResearchCore.Theme.Normalized

  @formula_regex ~r/[=<>±×÷\/*^]/

  @spec build(RetrievalRun.t(), Normalized.t() | nil, [Branch.t()]) :: [RawRecord.t()]
  def build(%RetrievalRun{} = retrieval_run, theme, branches \\ []) when is_list(branches) do
    documents_by_url = documents_by_url(retrieval_run.fetch_results)
    branches_by_key = branches_by_key(branches)

    retrieval_run.provider_results
    |> Enum.flat_map(fn provider_result ->
      Enum.map(provider_result.hits, fn %NormalizedSearchHit{} = hit ->
        build_raw_record(
          retrieval_run.id,
          hit,
          Map.get(documents_by_url, hit.url),
          theme,
          branch_for_hit(hit, branches_by_key)
        )
      end)
    end)
  end

  defp build_raw_record(
         retrieval_run_id,
         %NormalizedSearchHit{} = hit,
         fetched_document,
         theme,
         branch
       ) do
    %RawRecord{
      id: raw_record_id(retrieval_run_id, hit),
      search_hit: hit,
      fetched_document: fetched_document,
      retrieval_run_id: retrieval_run_id,
      branch: branch,
      theme: theme,
      raw_fields: raw_fields(hit, fetched_document)
    }
  end

  defp raw_fields(%NormalizedSearchHit{} = hit, fetched_document) do
    %{
      title: hit.title,
      url: hit.url,
      abstract: hit.snippet,
      content_excerpt: hit.snippet,
      identifiers: %{url: hit.url},
      source_label: source_label(hit.url)
    }
    |> maybe_put(:content, fetched_document && fetched_document.content)
    |> maybe_put(
      :formula_text,
      extract_formula_text(fetched_document && fetched_document.content)
    )
  end

  defp documents_by_url(fetch_results) do
    fetch_results
    |> Enum.reduce(%{}, fn
      %FetchResult{status: :ok, document: %{url: url} = document}, acc when is_binary(url) ->
        Map.put(acc, url, document)

      _other, acc ->
        acc
    end)
  end

  defp branches_by_key(branches) do
    Map.new(branches, fn %Branch{} = branch ->
      {{branch.kind, branch.label}, branch}
    end)
  end

  defp branch_for_hit(
         %NormalizedSearchHit{query: %{branch_kind: kind, branch_label: label}},
         branches
       )
       when not is_nil(kind) and is_binary(label) do
    Map.get(branches, {kind, label}) || recovered_branch(kind, label)
  end

  defp branch_for_hit(_hit, _branches), do: nil

  defp recovered_branch(kind, label) do
    %Branch{
      kind: kind,
      label: label,
      rationale: "Recovered from search query metadata",
      theme_relation: "derived"
    }
  end

  defp source_label(url) when is_binary(url) do
    url
    |> URI.parse()
    |> Map.get(:host)
  end

  defp source_label(_url), do: nil

  defp extract_formula_text(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.find(fn line ->
      line != "" and String.length(line) <= 200 and Regex.match?(@formula_regex, line)
    end)
  end

  defp extract_formula_text(_content), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp raw_record_id(retrieval_run_id, %NormalizedSearchHit{} = hit) do
    :crypto.hash(
      :sha256,
      "#{retrieval_run_id}:#{hit.provider}:#{hit.query.text}:#{hit.rank}:#{hit.url}"
    )
    |> Base.encode16(case: :lower)
    |> binary_part(0, 24)
    |> then(&"raw_record_#{&1}")
  end
end
