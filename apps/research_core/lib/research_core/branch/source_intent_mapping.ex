defmodule ResearchCore.Branch.SourceIntentMapping do
  @moduledoc """
  Deterministic intent-to-source-family mapping for branch planning.

  The mapper is intentionally explicit and keyword-driven so later
  source-scoped query generation can remain inspectable.
  """

  alias ResearchCore.Branch.{Branch, SourceFamily}
  alias ResearchCore.Theme.Normalized

  @docs_keywords [
    "api",
    "docs",
    "documentation",
    "readme",
    "sdk"
  ]

  @strong_docs_keywords [
    "docs",
    "documentation",
    "readme",
    "sdk"
  ]

  @research_overlap_keywords [
    "benchmark",
    "benchmarks",
    "evaluation",
    "evaluations",
    "evidence",
    "empirical"
  ]

  @ml_research_keywords [
    "alignment"
  ]

  @ml_context_keywords [
    "ai",
    "ml",
    "transformer",
    "machine learning",
    "artificial intelligence",
    "ai safety",
    "neural"
  ]

  @official_site_keywords [
    "fee schedule",
    "exchange fee schedule",
    "venue fee schedule",
    "fee rules",
    "exchange rules",
    "venue rules",
    "venue behavior",
    "exchange behavior"
  ]

  @official_site_full_intent_keywords [
    "exchange policy page",
    "venue policy page",
    "exchange policy document",
    "venue policy document",
    "exchange policy manual",
    "venue policy manual",
    "exchange docs page",
    "exchange docs document",
    "exchange docs manual",
    "venue docs page",
    "venue docs document",
    "venue docs manual",
    "exchange documentation page",
    "exchange documentation document",
    "exchange documentation manual",
    "venue documentation page",
    "venue documentation document",
    "venue documentation manual"
  ]

  @branch_only_official_site_labels [
    "exchange docs",
    "venue docs",
    "exchange documentation",
    "venue documentation"
  ]

  @econ_keywords [
    "economics",
    "economic",
    "market design",
    "working paper",
    "repec",
    "nber",
    "ssrn",
    "finance"
  ]

  @ml_keywords [
    "machine learning",
    "ml",
    "ai",
    "artificial intelligence",
    "transformer",
    "neural",
    "alignment",
    "benchmark"
  ]

  @academic_keywords [
    "paper",
    "papers",
    "preprint",
    "literature",
    "survey",
    "review",
    "research",
    "study",
    "scholarly"
  ]

  @type recommendation :: %{
          preferred_source_families: [SourceFamily.t()],
          rationale: String.t()
        }

  @doc """
  Maps a branch plus normalized theme into ordered preferred source families.
  """
  @spec recommend(Branch.t(), Normalized.t()) :: recommendation()
  def recommend(%Branch{} = branch, %Normalized{} = theme) do
    branch_label_text = normalize_text(branch.label)
    branch_signal_text = searchable_branch_text(branch)
    theme_signal_text = searchable_theme_text(theme)
    official_site_signal_text = searchable_official_site_text(branch, theme)
    official_site_signal_fields = searchable_official_site_fields(branch, theme)
    combined_signal_text = normalize_text([branch_signal_text, theme_signal_text])

    cond do
      official_site_intent?(
        branch,
        branch_label_text,
        official_site_signal_text,
        official_site_signal_fields
      ) ->
        %{
          preferred_source_families: [:official_sites, :official_docs, :general_web],
          rationale:
            "Venue and rule-oriented language biases the branch toward official sites before broader web search."
        }

      docs_intent?(branch_signal_text, theme_signal_text) ->
        %{
          preferred_source_families: [
            :official_docs,
            :code_repositories,
            :official_sites,
            :general_web
          ],
          rationale:
            "Documentation-oriented language biases the branch toward official documentation and repositories before broader web search."
        }

      econ_intent?(combined_signal_text) ->
        %{
          preferred_source_families: [:econ_working_papers, :academic_preprints, :general_web],
          rationale:
            "Economics-oriented language biases the branch toward working-paper sources before broader web search."
        }

      ml_intent?(combined_signal_text) ->
        %{
          preferred_source_families: [
            :academic_preprints,
            :conference_proceedings,
            :general_web
          ],
          rationale:
            "Machine-learning language biases the branch toward preprints and proceedings before broader web search."
        }

      academic_intent?(combined_signal_text) ->
        %{
          preferred_source_families: [
            :academic_preprints,
            :conference_proceedings,
            :general_web
          ],
          rationale:
            "Research-oriented language biases the branch toward academic sources before broader web search."
        }

      true ->
        %{
          preferred_source_families: [:general_web],
          rationale:
            "Fallback to general web because no stronger source-targeting intent was detected."
        }
    end
  end

  defp docs_intent?(branch_signal_text, theme_signal_text) do
    docs_signal_text = normalize_text([branch_signal_text, theme_signal_text])

    docs_keywords_present? = contains_any?(docs_signal_text, @docs_keywords)
    strong_docs_keywords_present? = contains_any?(docs_signal_text, @strong_docs_keywords)

    api_only_docs_intent? =
      contains_any?(docs_signal_text, ["api"]) and not strong_docs_keywords_present?

    docs_keywords_present? and
      not research_overlap_intent?(theme_signal_text) and
      not (api_only_docs_intent? and ml_intent?(theme_signal_text)) and
      not (strong_docs_keywords_present? and clear_ml_research_intent?(theme_signal_text))
  end

  defp research_overlap_intent?(theme_signal_text) do
    academic_intent?(theme_signal_text) or
      ml_research_overlap?(theme_signal_text) or
      econ_research_overlap?(theme_signal_text)
  end

  defp ml_research_overlap?(theme_signal_text) do
    ml_intent?(theme_signal_text) and contains_any?(theme_signal_text, @research_overlap_keywords)
  end

  defp clear_ml_research_intent?(theme_signal_text) do
    ml_intent?(theme_signal_text) and
      contains_any?(theme_signal_text, @ml_research_keywords) and
      contains_any?(theme_signal_text, @ml_context_keywords)
  end

  defp econ_research_overlap?(theme_signal_text) do
    econ_intent?(theme_signal_text) and
      contains_any?(theme_signal_text, @research_overlap_keywords)
  end

  defp official_site_intent?(
         %Branch{} = branch,
         branch_label_text,
         official_site_signal_text,
         official_site_signal_fields
       ) do
    direct_branch_official_site_label?(branch, branch_label_text) or
      contains_any?(official_site_signal_text, @official_site_keywords) or
      contains_exact_phrase?(official_site_signal_fields, @official_site_full_intent_keywords)
  end

  defp direct_branch_official_site_label?(%Branch{kind: :direct}, branch_label_text) do
    branch_label_text in @branch_only_official_site_labels
  end

  defp direct_branch_official_site_label?(%Branch{}, _branch_label_text), do: false

  defp econ_intent?(combined_text) do
    contains_any?(combined_text, @econ_keywords)
  end

  defp ml_intent?(combined_text) do
    contains_any?(combined_text, @ml_keywords)
  end

  defp academic_intent?(combined_text) do
    contains_any?(combined_text, @academic_keywords)
  end

  defp searchable_branch_text(%Branch{} = branch) do
    [branch.label, branch.theme_relation]
    |> normalize_text()
  end

  defp searchable_theme_text(%Normalized{} = theme) do
    [
      theme.topic,
      theme.original_input,
      theme.normalized_text,
      objective_text(theme),
      Enum.map(theme.domain_hints, & &1.label),
      Enum.map(theme.mechanism_hints, & &1.label),
      Enum.map(theme.constraints, & &1.description),
      theme.notes
    ]
    |> normalize_text()
  end

  defp searchable_official_site_text(%Branch{} = branch, %Normalized{} = theme) do
    [
      branch.label,
      theme.topic,
      theme.original_input,
      theme.normalized_text,
      objective_text(theme),
      theme.notes
    ]
    |> normalize_text()
  end

  defp searchable_official_site_fields(%Branch{} = branch, %Normalized{} = theme) do
    [
      branch.label,
      theme.topic,
      theme.original_input,
      theme.normalized_text,
      objective_text(theme),
      theme.notes
    ]
    |> Enum.map(&normalize_text/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp objective_text(%Normalized{objective: nil}), do: nil
  defp objective_text(%Normalized{objective: objective}), do: objective.description

  defp contains_any?(text, keywords) do
    tokens = MapSet.new(String.split(text, " ", trim: true))

    Enum.any?(keywords, fn keyword ->
      contains_keyword?(text, tokens, keyword)
    end)
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

  defp contains_exact_phrase?(fields, keywords) do
    Enum.any?(fields, fn field ->
      Enum.any?(keywords, fn keyword ->
        normalized_keyword = normalize_text(keyword)
        field == normalized_keyword
      end)
    end)
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
