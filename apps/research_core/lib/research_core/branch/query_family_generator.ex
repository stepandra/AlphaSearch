defmodule ResearchCore.Branch.QueryFamilyGenerator do
  @moduledoc """
  Pure function module that generates query families for a research branch.

  Given a `Branch.t()` and the source `Normalized.t()` theme, produces one
  `QueryFamily.t()` per family kind (6 total), composing search query strings
  deterministically from the branch label and theme fields. The
  `:source_scoped` family emits explicit `site:`-scoped variants when the
  branch maps to source families with canonical scoped patterns.
  """

  alias ResearchCore.Branch.{
    Branch,
    QueryFamily,
    QueryFamilyKind,
    SearchQuery,
    SourceFamily,
    SourceHint,
    SourceIntentMapping
  }

  alias ResearchCore.Theme.Normalized

  @doc """
  Generates a list of `QueryFamily.t()` for all 6 family kinds from a branch and theme.

  Returns families in the canonical order defined by `QueryFamilyKind.all/0`.
  """
  @spec generate(Branch.t(), Normalized.t()) :: [QueryFamily.t()]
  def generate(%Branch{} = branch, %Normalized{} = theme) do
    seed = seed_query(branch, theme)
    recommendation = SourceIntentMapping.recommend(branch, theme)

    Enum.map(QueryFamilyKind.all(), &build_family(&1, branch, theme, seed, recommendation))
  end

  # -- Family builders --

  defp build_family(:precision, branch, theme, seed, _recommendation) do
    queries =
      [
        query(branch, branch.label, seed),
        if(theme.objective,
          do: query(branch, join_terms([branch.label, theme.objective.description]), seed)
        )
      ]
      |> Enum.reject(&is_nil/1)

    %QueryFamily{
      kind: :precision,
      rationale: "Tight, exact queries for high-relevance results",
      queries: queries
    }
  end

  defp build_family(:recall, branch, theme, seed, _recommendation) do
    base = topic_words(theme.topic, seed)

    domain_terms =
      theme.domain_hints
      |> Enum.map(& &1.label)
      |> Enum.map(&normalize_text/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.take(2)

    recall_phrases =
      case domain_terms do
        [] -> [base]
        terms -> [base | Enum.map(terms, &join_terms([base, &1]))]
      end

    mechanism_terms =
      theme.mechanism_hints
      |> Enum.map(& &1.label)
      |> Enum.map(&normalize_text/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.take(1)

    recall_phrases =
      case mechanism_terms do
        [] -> recall_phrases
        [m] -> recall_phrases ++ [join_terms([base, m])]
      end

    queries = Enum.map(recall_phrases, &query(branch, &1, seed))

    %QueryFamily{
      kind: :recall,
      rationale: "Broader queries for wider coverage across related literature",
      queries: queries
    }
  end

  defp build_family(:synonym_alias, branch, theme, seed, _recommendation) do
    domain_labels = Enum.map(theme.domain_hints, & &1.label)
    mechanism_labels = Enum.map(theme.mechanism_hints, & &1.label)

    alt_terms =
      (domain_labels ++ mechanism_labels)
      |> Enum.map(&normalize_text/1)
      |> Enum.reject(&(&1 == ""))

    topic_context = first_present([theme.topic, branch.label, seed])

    queries =
      case alt_terms do
        [] ->
          [query(branch, join_terms([branch.label, "alternative terminology"]), seed)]

        terms ->
          Enum.map(Enum.take(terms, 3), fn term ->
            query(branch, join_terms([term, topic_context]), seed)
          end)
      end

    %QueryFamily{
      kind: :synonym_alias,
      rationale: "Alternative terminology and aliases for cross-vocabulary coverage",
      queries: queries
    }
  end

  defp build_family(:literature_format, branch, theme, seed, _recommendation) do
    base = first_present([branch.label, seed])

    queries = [
      query(branch, join_terms(["\"#{base}\"", "working paper"]), seed),
      query(branch, join_terms(["\"#{base}\"", "survey review"]), seed)
    ]

    queries =
      case present_string(theme.objective && theme.objective.description) do
        nil ->
          queries

        desc ->
          queries ++ [query(branch, join_terms(["\"#{desc}\"", theme.topic, "paper"]), seed)]
      end

    %QueryFamily{
      kind: :literature_format,
      rationale: "Academic and publication-specific phrasing for scholarly sources",
      queries: queries
    }
  end

  defp build_family(:venue_specific, branch, theme, seed, _recommendation) do
    domain_labels = Enum.map(theme.domain_hints, & &1.label)

    {queries, has_hints} = venue_queries(branch, domain_labels, theme.topic)

    queries =
      if has_hints do
        queries
      else
        [query(branch, join_terms([branch.label, theme.topic]), seed)]
      end

    %QueryFamily{
      kind: :venue_specific,
      rationale: "Venue or platform-specific queries targeting known sources",
      queries: queries
    }
  end

  defp build_family(:source_scoped, branch, theme, _seed, recommendation) do
    queries = source_scoped_queries(branch, theme, recommendation.preferred_source_families)

    %QueryFamily{
      kind: :source_scoped,
      rationale:
        recommendation.rationale <>
          " Canonical `site:`-scoped queries are emitted before broader web fallbacks whenever explicit patterns exist.",
      source_families: recommendation.preferred_source_families,
      queries: queries
    }
  end

  # -- Venue inference --

  @venue_map [
    {"prediction market", [{"Kalshi", "Kalshi"}, {"Polymarket", "Polymarket"}]},
    {"options", [{"CBOE", "CBOE"}, {"SSRN", "SSRN"}]},
    {"machine learning", [{"arXiv", "arXiv"}, {"NeurIPS", "NeurIPS"}]},
    {"crypto", [{"Dune Analytics", "Dune Analytics"}, {"Messari", "Messari"}]},
    {"finance", [{"SSRN", "SSRN"}, {"NBER", "NBER"}]}
  ]

  defp venue_queries(%Branch{} = branch, domain_labels, topic) do
    all_text =
      join_terms([branch.label, Enum.join(domain_labels, " "), topic])
      |> String.downcase()

    venues =
      @venue_map
      |> Enum.filter(fn {keyword, _} -> String.contains?(all_text, keyword) end)
      |> Enum.flat_map(fn {_, venues} -> venues end)
      |> Enum.uniq_by(fn {name, _} -> name end)
      |> Enum.take(3)

    case venues do
      [] ->
        {[], false}

      venues ->
        queries =
          Enum.map(venues, fn {venue_name, venue_label} ->
            query(branch, join_terms([branch.label, venue_name]), branch.label,
              source_hints: [%SourceHint{label: venue_label}]
            )
          end)

        {queries, true}
    end
  end

  defp source_scoped_queries(%Branch{} = branch, %Normalized{} = theme, source_families) do
    scoped_seed = scoped_seed_query(branch, theme)

    source_families
    |> Enum.flat_map(fn family ->
      family
      |> scoped_patterns(branch, theme)
      |> Enum.map(fn pattern ->
        query(branch, join_terms([pattern, scoped_seed]), scoped_seed,
          scope_type: :source_scoped,
          source_family: family,
          scoped_pattern: pattern
        )
      end)
    end)
  end

  defp scoped_patterns(:official_sites, %Branch{} = branch, %Normalized{} = theme) do
    SourceFamily.official_site_patterns([
      branch.label,
      theme.topic,
      objective_text(theme),
      Enum.map(theme.domain_hints, & &1.label),
      Enum.map(theme.mechanism_hints, & &1.label)
    ])
  end

  defp scoped_patterns(family, _branch, _theme) do
    SourceFamily.site_patterns(family)
  end

  # -- Helpers --

  defp query(%Branch{} = branch, text, fallback, options \\ []) do
    %SearchQuery{
      text: first_present([text, fallback, "research"]),
      source_hints: Keyword.get(options, :source_hints, []),
      scope_type: Keyword.get(options, :scope_type, :generic),
      source_family: Keyword.get(options, :source_family),
      scoped_pattern: Keyword.get(options, :scoped_pattern),
      branch_kind: branch.kind,
      branch_label: branch.label
    }
  end

  defp topic_words(topic, fallback) do
    first_present([topic, fallback, "research"])
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(4)
    |> Enum.join(" ")
  end

  defp seed_query(branch, theme) do
    first_present([
      branch.label,
      theme.topic,
      theme.normalized_text,
      theme.original_input,
      "research"
    ])
  end

  defp scoped_seed_query(%Branch{kind: :mechanism, label: label}, %Normalized{} = theme) do
    first_present([
      join_terms([label, first_mechanism(theme)]),
      label,
      theme.topic,
      "research"
    ])
  end

  defp scoped_seed_query(%Branch{kind: :method, label: label}, %Normalized{} = theme) do
    first_present([
      join_terms([label, first_present([objective_text(theme), first_mechanism(theme)])]),
      label,
      theme.topic,
      "research"
    ])
  end

  defp scoped_seed_query(%Branch{label: label}, %Normalized{} = theme) do
    first_present([
      join_terms([label, objective_text(theme)]),
      label,
      theme.topic,
      "research"
    ])
  end

  defp objective_text(%Normalized{objective: nil}), do: nil
  defp objective_text(%Normalized{objective: objective}), do: objective.description

  defp first_mechanism(%Normalized{mechanism_hints: mechanism_hints}) do
    mechanism_hints
    |> Enum.map(& &1.label)
    |> Enum.find(&(present_string(&1) != nil))
  end

  defp join_terms(terms) do
    terms
    |> Enum.map(&present_string/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp first_present(terms) do
    Enum.find_value(terms, &present_string/1)
  end

  defp present_string(value) do
    case normalize_text(value) do
      "" -> nil
      text -> text
    end
  end

  defp normalize_text(value) when is_binary(value) do
    value
    |> String.split(~r/\s+/, trim: true)
    |> Enum.join(" ")
  end

  defp normalize_text(_), do: ""
end
