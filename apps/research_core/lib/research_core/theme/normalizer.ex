defmodule ResearchCore.Theme.Normalizer do
  @moduledoc """
  Normalizes raw research theme text into a structured `Normalized` struct.

  Pure functions only. Deterministic output for a given input.

  ## What normalization does

  - Validates input (rejects empty, whitespace-only, nil, and non-binary values)
  - Trims and collapses duplicate whitespace
  - Stores `normalized_text` as the cleaned input
  - Sets `topic` to `normalized_text` for now
  - Identifies domain hints from known labels
  - Identifies mechanism hints from known labels
  - Extracts objectives signaled by action keywords
  - Extracts heuristic constraints signaled by comparison/exclusion keywords
  - Preserves original input verbatim

  ## What normalization does NOT do

  - Generate search queries or research branches
  - Call external APIs or LLMs
  - Perform semantic analysis beyond keyword matching
  - Guarantee exhaustive extraction — hints are best-effort from known labels
  - Perform dedicated topic extraction — `topic` currently falls back to `normalized_text`
  """

  alias ResearchCore.Theme.{Normalized, Objective, Constraint, DomainHint, MechanismHint}

  @domain_labels %{
    "prediction market" => "prediction-markets",
    "prediction markets" => "prediction-markets",
    "prediction contract" => "prediction-markets",
    "prediction contracts" => "prediction-markets",
    "options" => "options",
    "options skew" => "options",
    "options pricing" => "options",
    "otm" => "options",
    "sports betting" => "sports-betting",
    "sportsbook" => "sports-betting",
    "sportbook" => "sports-betting",
    "forex" => "forex",
    "crypto" => "crypto",
    "equities" => "equities",
    "futures" => "futures",
    "fixed income" => "fixed-income",
    "defi" => "defi"
  }

  @mechanism_labels %{
    "order-book" => "order-book",
    "order book" => "order-book",
    "orderbook" => "order-book",
    "routing" => "routing",
    "cross-exchange" => "cross-exchange",
    "cross exchange" => "cross-exchange",
    "skew" => "skew",
    "arbitrage" => "arbitrage",
    "market making" => "market-making",
    "market-making" => "market-making",
    "hedging" => "hedging",
    "liquidity" => "liquidity",
    "volatility" => "volatility",
    "mean reversion" => "mean-reversion",
    "momentum" => "momentum"
  }

  @objective_keywords ~w(help find look discover identify explore investigate analyze determine assess)

  @constraint_patterns [
    {~r/better than\s+(.+?)(?:\?|$|,|;)/i, :methodological},
    {~r/without\s+(.+?)(?:\?|$|,|;)/i, :scope},
    {~r/(?:^|\s)only\s+(.+?)(?:\?|$|,|;)/i, :scope},
    {~r/excluding\s+(.+?)(?:\?|$|,|;)/i, :scope},
    {~r/limited to\s+(.+?)(?:\?|$|,|;)/i, :scope},
    {~r/no more than\s+(.+?)(?:\?|$|,|;)/i, :scope},
    {~r/must not\s+(.+?)(?:\?|$|,|;)/i, :scope}
  ]

  @doc """
  Normalizes raw theme text into a structured `Normalized` struct.

  Returns `{:ok, Normalized.t()}` on success, or `{:error, reason}` on validation failure.

  ## Examples

      iex> ResearchCore.Theme.Normalizer.normalize("Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?")
      {:ok, %ResearchCore.Theme.Normalized{original_input: "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?", normalized_text: "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?", topic: "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?", domain_hints: [%ResearchCore.Theme.DomainHint{label: "prediction-markets"}, %ResearchCore.Theme.DomainHint{label: "options"}], mechanism_hints: [%ResearchCore.Theme.MechanismHint{label: "order-book"}], objective: %ResearchCore.Theme.Objective{description: "help recalibrate cheap OTM prediction contracts better than price alone?"}, constraints: [%ResearchCore.Theme.Constraint{description: "price alone?", kind: :methodological}], notes: nil}}
  """
  @spec normalize(term()) :: {:ok, Normalized.t()} | {:error, atom()}
  def normalize(nil), do: {:error, :empty_input}
  def normalize(""), do: {:error, :empty_input}
  def normalize(raw_text) when not is_binary(raw_text), do: {:error, :invalid_input_type}

  def normalize(raw_text) when is_binary(raw_text) do
    case String.trim(raw_text) do
      "" ->
        {:error, :whitespace_only}

      trimmed ->
        normalized_text = collapse_whitespace(trimmed)
        normalized_lookup = normalize_lookup_text(normalized_text)
        topic = extract_topic(normalized_text)

        {:ok,
         %Normalized{
           original_input: raw_text,
           normalized_text: normalized_text,
           topic: topic,
           domain_hints: extract_domain_hints(normalized_lookup),
           mechanism_hints: extract_mechanism_hints(normalized_lookup),
           objective: extract_objective(normalized_lookup, normalized_text),
           constraints: extract_constraints(normalized_text),
           notes: nil
         }}
    end
  end

  defp collapse_whitespace(text) do
    text
    |> String.replace(~r/\s+/, " ")
  end

  defp normalize_lookup_text(text), do: String.downcase(text)

  defp extract_topic(normalized_text), do: normalized_text

  defp extract_domain_hints(normalized_lookup) do
    @domain_labels
    |> Enum.filter(fn {pattern, _label} -> contains_phrase?(normalized_lookup, pattern) end)
    |> Enum.map(fn {_pattern, label} -> label end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn label -> %DomainHint{label: label} end)
  end

  defp extract_mechanism_hints(normalized_lookup) do
    @mechanism_labels
    |> Enum.filter(fn {pattern, _label} -> contains_phrase?(normalized_lookup, pattern) end)
    |> Enum.map(fn {_pattern, label} -> label end)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn label -> %MechanismHint{label: label} end)
  end

  defp extract_objective(normalized_lookup, normalized_text) do
    keyword_match =
      Enum.find(@objective_keywords, fn keyword ->
        contains_phrase?(normalized_lookup, keyword)
      end)

    case keyword_match do
      nil ->
        nil

      keyword ->
        case Regex.run(~r/(^|[^[:alnum:]])#{Regex.escape(keyword)}\s+(.+)/i, normalized_text) do
          [_, _, rest] -> %Objective{description: String.trim(rest)}
          _ -> %Objective{description: normalized_text}
        end
    end
  end

  defp extract_constraints(normalized_text) do
    @constraint_patterns
    |> Enum.flat_map(fn {pattern, kind} ->
      case Regex.run(pattern, normalized_text) do
        [_, captured] ->
          captured = String.trim(captured)

          if captured == "" do
            []
          else
            [%Constraint{description: captured, kind: kind}]
          end

        _ ->
          []
      end
    end)
    |> Enum.uniq_by(fn %Constraint{description: description, kind: kind} ->
      {description, kind}
    end)
  end

  defp contains_phrase?(normalized_lookup, phrase) do
    Regex.match?(
      ~r/(^|[^[:alnum:]])#{Regex.escape(phrase)}(?=$|[^[:alnum:]])/i,
      normalized_lookup
    )
  end
end
