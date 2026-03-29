defmodule ResearchCore.Branch.SourceFamily do
  @moduledoc """
  Enumerates the supported preferred source-family categories used for
  deterministic source-targeting decisions.
  """

  @official_site_patterns_by_keyword [
    {"kalshi", "site:kalshi.com"},
    {"polymarket", "site:polymarket.com"},
    {"cboe", "site:cboe.com"},
    {"dune analytics", "site:dune.com"},
    {"dune", "site:dune.com"},
    {"messari", "site:messari.io"}
  ]

  @families [
    :academic_preprints,
    :econ_working_papers,
    :conference_proceedings,
    :official_docs,
    :official_sites,
    :code_repositories,
    :general_web
  ]

  @site_patterns %{
    academic_preprints: ["site:arxiv.org", "site:ssrn.com", "site:papers.ssrn.com", "site:osf.io"],
    econ_working_papers: [
      "site:nber.org",
      "site:ideas.repec.org",
      "site:econpapers.repec.org"
    ],
    conference_proceedings: [
      "site:openreview.net",
      "site:proceedings.mlr.press",
      "site:dl.acm.org"
    ],
    official_docs: ["site:readthedocs.io", "site:docs."],
    official_sites: [],
    code_repositories: ["site:github.com"],
    general_web: []
  }

  @type t ::
          :academic_preprints
          | :econ_working_papers
          | :conference_proceedings
          | :official_docs
          | :official_sites
          | :code_repositories
          | :general_web

  @doc "Returns the ordered list of all supported source families."
  @spec all() :: [t()]
  def all, do: @families

  @doc "Returns `true` when the source family is supported."
  @spec valid?(atom()) :: boolean()
  def valid?(family) when family in @families, do: true
  def valid?(_family), do: false

  @doc "Returns the canonical `site:` patterns associated with a source family."
  @spec site_patterns(t()) :: [String.t()]
  def site_patterns(family) when family in @families, do: Map.fetch!(@site_patterns, family)

  @doc "Returns explicit official-site `site:` patterns inferred from venue or project hints."
  @spec official_site_patterns(String.t() | [term()]) :: [String.t()]
  def official_site_patterns(signals) do
    normalized = normalize_text(signals)
    tokens = MapSet.new(String.split(normalized, " ", trim: true))

    @official_site_patterns_by_keyword
    |> Enum.filter(fn {keyword, _pattern} -> contains_keyword?(normalized, tokens, keyword) end)
    |> Enum.map(&elem(&1, 1))
  end

  defp contains_keyword?(_text, _tokens, keyword) when keyword in [nil, ""], do: false

  defp contains_keyword?(text, tokens, keyword) do
    normalized_keyword = normalize_text(keyword)

    case String.split(normalized_keyword, " ", trim: true) do
      [] ->
        false

      [single_token] ->
        MapSet.member?(tokens, single_token)

      _multiple_tokens ->
        String.contains?(" " <> text <> " ", " " <> normalized_keyword <> " ")
    end
  end

  defp normalize_text(values) when is_list(values) do
    values
    |> List.flatten()
    |> Enum.map(&normalize_text/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  defp normalize_text(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^[:alnum:]]+/u, " ")
    |> String.split(~r/\s+/, trim: true)
    |> Enum.join(" ")
  end

  defp normalize_text(_value), do: ""
end
