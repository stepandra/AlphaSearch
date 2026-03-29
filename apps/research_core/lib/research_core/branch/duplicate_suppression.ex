defmodule ResearchCore.Branch.DuplicateSuppression do
  @moduledoc """
  Deterministically suppresses duplicate and near-duplicate search queries.

  Duplicate detection is intentionally simple and inspectable:

  - exact string equality
  - whitespace-normalized, case-folded equality
  - simple near-duplicate equality based on sorted alphanumeric tokens

  The first query wins for text ordering and representation. When later
  duplicates include additional source hints, those hints are merged into the
  representative query so venue guidance is not lost.
  """

  alias ResearchCore.Branch.{SearchQuery, SourceHint}

  @doc """
  Removes duplicate and near-duplicate queries while preserving encounter order.
  """
  @spec deduplicate([SearchQuery.t()]) :: [SearchQuery.t()]
  def deduplicate(queries) when is_list(queries) do
    {deduplicated, _seen} =
      Enum.reduce(queries, {[], %{}}, fn %SearchQuery{} = query, {acc, seen} ->
        keys = suppression_keys(query)

        case first_seen_index(keys, seen) do
          nil ->
            index = length(acc)
            {acc ++ [query], remember_keys(seen, keys, index)}

          index ->
            merged_queries = List.update_at(acc, index, &merge_queries(&1, query))
            {merged_queries, remember_keys(seen, keys, index)}
        end
      end)

    deduplicated
  end

  defp first_seen_index(keys, seen) do
    Enum.find_value(keys, &Map.get(seen, &1))
  end

  defp remember_keys(seen, keys, index) do
    Enum.reduce(keys, seen, fn key, acc -> Map.put(acc, key, index) end)
  end

  defp merge_queries(%SearchQuery{} = kept, %SearchQuery{} = duplicate) do
    %SearchQuery{
      kept
      | source_hints: merge_source_hints(kept.source_hints, duplicate.source_hints)
    }
  end

  defp merge_source_hints(left, right) do
    (left ++ right)
    |> Enum.reduce({MapSet.new(), []}, fn %SourceHint{} = hint, {seen, acc} ->
      key = normalize_hint_label(hint.label)

      if MapSet.member?(seen, key) do
        {seen, acc}
      else
        {MapSet.put(seen, key), acc ++ [hint]}
      end
    end)
    |> elem(1)
  end

  defp suppression_keys(%SearchQuery{text: text}) do
    normalized = normalized_key(text)
    token_sorted = token_sorted_key(text)

    [exact_key(text), normalized_key_tag(normalized), near_duplicate_key_tag(token_sorted)]
    |> Enum.uniq()
  end

  defp exact_key(text), do: "exact:" <> text
  defp normalized_key_tag(text), do: "normalized:" <> text
  defp near_duplicate_key_tag(text), do: "near:" <> text

  defp normalized_key(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> Enum.join(" ")
    |> String.downcase()
  end

  defp token_sorted_key(text) do
    text
    |> String.downcase()
    |> then(&Regex.scan(~r/[[:alnum:]]+/u, &1))
    |> List.flatten()
    |> Enum.sort()
    |> Enum.join(" ")
  end

  defp normalize_hint_label(label) when is_binary(label) do
    label
    |> String.split(~r/\s+/, trim: true)
    |> Enum.join(" ")
    |> String.downcase()
  end

  defp normalize_hint_label(_), do: ""
end
