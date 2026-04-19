defmodule ResearchCore.Strategy.Helpers do
  @moduledoc false

  @citation_regex ~r/REC_\d{4}/
  @known_sections %{
    "taxonomy" => :taxonomy_and_thematic_grouping,
    "taxonomy_and_thematic_grouping" => :taxonomy_and_thematic_grouping,
    "directly_reusable_formulas" => :reusable_formulas,
    "reusable_formulas" => :reusable_formulas,
    "prototype_recommendations" => :next_prototype_recommendations,
    "next_prototype_recommendations" => :next_prototype_recommendations,
    "ranked_papers_key_findings" => :ranked_important_papers_and_findings,
    "ranked_important_papers_and_findings" => :ranked_important_papers_and_findings,
    "executive_summary" => :executive_summary,
    "open_gaps" => :open_gaps,
    "evidence_appendix" => :evidence_appendix,
    "key_findings" => :ranked_important_papers_and_findings
  }

  @spec fetch(map() | struct(), atom(), term()) :: term()
  def fetch(value, key, default \\ nil)

  def fetch(%_{} = value, key, default), do: fetch(Map.from_struct(value), key, default)

  def fetch(value, key, default) when is_map(value) do
    Map.get(value, key, Map.get(value, Atom.to_string(key), default))
  end

  def fetch(_value, _key, default), do: default

  @spec atomize(term(), [atom()], atom()) :: atom()
  def atomize(value, allowed, default) when is_binary(value) do
    normalized =
      value
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "_")
      |> String.trim("_")

    Enum.find(allowed, default, fn candidate -> Atom.to_string(candidate) == normalized end)
  end

  def atomize(value, allowed, default) when is_atom(value) do
    if value in allowed, do: value, else: default
  end

  def atomize(_value, _allowed, default), do: default

  @spec normalize_string(term()) :: String.t() | nil
  def normalize_string(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      string -> string
    end
  end

  def normalize_string(_value), do: nil

  @spec normalize_string_list(term()) :: [String.t()]
  def normalize_string_list(values) when is_list(values) do
    values
    |> Enum.map(&normalize_string/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  def normalize_string_list(value) when is_binary(value), do: [value] |> normalize_string_list()
  def normalize_string_list(_value), do: []

  @spec extract_cited_keys(String.t()) :: [String.t()]
  def extract_cited_keys(markdown) when is_binary(markdown) do
    @citation_regex
    |> Regex.scan(markdown)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec slug(term()) :: atom()
  def slug(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
    |> canonical_section_id()
  end

  def slug(value) when is_atom(value), do: value

  @spec normalize_notes(term()) :: [String.t()]
  def normalize_notes(value) when is_binary(value), do: [value] |> normalize_notes()

  def normalize_notes(values) when is_list(values) do
    values
    |> Enum.map(&normalize_string/1)
    |> Enum.reject(&is_nil/1)
  end

  def normalize_notes(_value), do: []

  defp canonical_section_id(value), do: Map.get(@known_sections, value, :unknown_section)
end
