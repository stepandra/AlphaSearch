defmodule ResearchCore.Theme.NormalizerEdgeCasesTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Theme.Normalizer
  alias ResearchCore.Theme.{Normalized, Objective, Constraint, DomainHint, MechanismHint}

  # ---------------------------------------------------------------------------
  # 1. Noisy themes — extra punctuation and mixed case
  # ---------------------------------------------------------------------------
  describe "noisy themes with extra punctuation and mixed case" do
    test "mixed case domain labels are recognized" do
      input = "Can ORDER-BOOK state help recalibrate cheap OTM PREDICTION CONTRACTS?"

      assert {:ok, %Normalized{domain_hints: hints}} = Normalizer.normalize(input)
      labels = Enum.map(hints, & &1.label)
      assert "prediction-markets" in labels
    end

    test "mixed case mechanism labels are recognized" do
      input = "Can ORDER-BOOK state help recalibrate cheap OTM prediction contracts?"

      assert {:ok, %Normalized{mechanism_hints: hints}} = Normalizer.normalize(input)
      labels = Enum.map(hints, & &1.label)
      assert "order-book" in labels
    end

    test "theme with excessive punctuation still extracts topic" do
      input =
        "!!!Find transferable literature...from options skew---and sportsbook longshot demand!!!"

      assert {:ok, %Normalized{normalized_text: normalized_text, topic: topic}} =
               Normalizer.normalize(input)

      assert is_binary(normalized_text)
      assert String.length(normalized_text) > 0
      assert topic == normalized_text
    end

    test "theme with ellipsis and dashes preserves original input" do
      input =
        "!!!Find transferable literature...from options skew---and sportsbook longshot demand!!!"

      assert {:ok, %Normalized{original_input: ^input}} = Normalizer.normalize(input)
    end

    test "ALL CAPS input still extracts objective keywords" do
      input = "HELP RECALIBRATE CHEAP OTM PREDICTION CONTRACTS BETTER THAN PRICE ALONE"

      assert {:ok, %Normalized{objective: %Objective{description: desc}}} =
               Normalizer.normalize(input)

      assert is_binary(desc)
    end

    test "mixed case with extra question marks normalizes" do
      input = "can order-book state HELP recalibrate??? better than price alone???"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)
      assert result.mechanism_hints != []
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Duplicate spacing and tab characters
  # ---------------------------------------------------------------------------
  describe "duplicate spacing and tab characters" do
    test "multiple spaces between words are collapsed to single space" do
      input = "Find    alpha    in    prediction    markets"

      assert {:ok, %Normalized{normalized_text: normalized_text, topic: topic}} =
               Normalizer.normalize(input)

      refute normalized_text =~ ~r/\s{2,}/
      assert normalized_text == "Find alpha in prediction markets"
      assert topic == normalized_text
    end

    test "tab characters are collapsed to spaces" do
      input = "Find\talpha\tin\tprediction\tmarkets"

      assert {:ok, %Normalized{normalized_text: normalized_text}} = Normalizer.normalize(input)
      refute normalized_text =~ ~r/\t/
      assert normalized_text == "Find alpha in prediction markets"
    end

    test "mixed tabs spaces and newlines are collapsed" do
      input = "Look for \t cross-exchange \n routing  alpha \t\n between prediction markets"

      assert {:ok, %Normalized{normalized_text: normalized_text}} = Normalizer.normalize(input)
      refute normalized_text =~ ~r/\s{2,}/
      refute normalized_text =~ ~r/[\t\n]/
    end

    test "leading/trailing tabs are trimmed" do
      input = "\t\t  Look for routing alpha  \t\t"

      assert {:ok, %Normalized{normalized_text: normalized_text}} = Normalizer.normalize(input)
      refute String.starts_with?(normalized_text, " ")
      refute String.starts_with?(normalized_text, "\t")
      refute String.ends_with?(normalized_text, " ")
      refute String.ends_with?(normalized_text, "\t")
    end

    test "original_input preserved with all whitespace artifacts" do
      raw = "\t  Find   alpha\tin  markets  \n"

      assert {:ok, %Normalized{original_input: ^raw}} = Normalizer.normalize(raw)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Empty string and whitespace-only input
  # ---------------------------------------------------------------------------
  describe "empty and whitespace-only input edge cases" do
    test "empty string returns :empty_input" do
      assert {:error, :empty_input} = Normalizer.normalize("")
    end

    test "nil returns :empty_input" do
      assert {:error, :empty_input} = Normalizer.normalize(nil)
    end

    test "single space returns :whitespace_only" do
      assert {:error, :whitespace_only} = Normalizer.normalize(" ")
    end

    test "multiple spaces returns :whitespace_only" do
      assert {:error, :whitespace_only} = Normalizer.normalize("     ")
    end

    test "tabs only returns :whitespace_only" do
      assert {:error, :whitespace_only} = Normalizer.normalize("\t\t\t")
    end

    test "newlines only returns :whitespace_only" do
      assert {:error, :whitespace_only} = Normalizer.normalize("\n\n\n")
    end

    test "mixed whitespace chars returns :whitespace_only" do
      assert {:error, :whitespace_only} = Normalizer.normalize(" \t \n \r\n \t ")
    end

    test "non-binary input returns :invalid_input_type" do
      assert {:error, :invalid_input_type} = Normalizer.normalize(42)
      assert {:error, :invalid_input_type} = Normalizer.normalize(:atom_input)
      assert {:error, :invalid_input_type} = Normalizer.normalize(["list"])
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Ambiguous but valid input — no clear domain or mechanism
  # ---------------------------------------------------------------------------
  describe "ambiguous but valid input" do
    test "generic research question with no domain or mechanism" do
      input = "What general patterns emerge from cross-asset correlation analysis?"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)
      assert result.domain_hints == []
      assert result.mechanism_hints == []
      assert is_binary(result.topic)
      assert result.original_input == input
    end

    test "plain English sentence with no keywords" do
      input = "Quantitative approaches to modeling uncertainty in complex systems"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)
      assert result.domain_hints == []
      assert result.mechanism_hints == []
      assert result.objective == nil
      assert result.constraints == []
    end

    test "single word input is valid" do
      input = "arbitrage"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)
      assert result.topic == "arbitrage"
      assert result.mechanism_hints != []
      labels = Enum.map(result.mechanism_hints, & &1.label)
      assert "arbitrage" in labels
    end

    test "word boundary matching avoids substring hits inside larger words" do
      input = "We discussed adoptions and rerouting in product onboarding"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)
      assert result.domain_hints == []
      assert result.mechanism_hints == []
      assert result.objective == nil
    end

    test "objective keywords do not match inside larger words" do
      input = "Outlook on fragmented markets remains uncertain"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)
      assert result.objective == nil
    end

    test "whole-word matches still allow documented semantic false positives" do
      # 'options' can mean financial options or generic 'choices'
      input = "What are my options for dinner tonight?"

      assert {:ok, %Normalized{domain_hints: hints}} = Normalizer.normalize(input)
      # Whole-word matching still allows this semantic false positive.
      labels = Enum.map(hints, & &1.label)
      assert "options" in labels
    end

    test "input with only punctuation and letters, no known terms" do
      input = "Some purely abstract philosophical reasoning about epistemology"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)
      assert result.domain_hints == []
      assert result.mechanism_hints == []
      assert result.objective == nil
      assert result.constraints == []
      assert result.topic == input
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Themes with multiple objectives or constraints
  # ---------------------------------------------------------------------------
  describe "themes with multiple objectives or constraints" do
    test "input with multiple constraint patterns" do
      input =
        "Find alpha in prediction markets better than random selection, without using proprietary data, excluding illiquid venues"

      assert {:ok, %Normalized{constraints: constraints}} = Normalizer.normalize(input)
      assert length(constraints) >= 2

      kinds = Enum.map(constraints, & &1.kind)
      descriptions = Enum.map(constraints, & &1.description)

      assert :methodological in kinds
      assert :scope in kinds
      assert Enum.any?(descriptions, &String.contains?(&1, "random"))
    end

    test "input with 'better than' and 'must not' constraints" do
      input =
        "Help identify arbitrage in crypto better than basic spread detection; must not rely on centralized order feeds"

      assert {:ok, %Normalized{constraints: constraints}} = Normalizer.normalize(input)
      assert length(constraints) >= 2
    end

    test "multiple objective keywords — first match wins" do
      input = "Help find and discover routing patterns in prediction markets"

      assert {:ok, %Normalized{objective: %Objective{description: desc}}} =
               Normalizer.normalize(input)

      # 'help' appears first in the keyword list
      assert is_binary(desc)
      assert String.length(desc) > 0
    end

    test "constraint with objective in same sentence" do
      input = "Find transferable skew patterns better than naive regression models"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)
      assert %Objective{} = result.objective
      assert length(result.constraints) >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Very long input strings
  # ---------------------------------------------------------------------------
  describe "very long input strings" do
    test "normalizes a theme with 500+ characters" do
      base = "Explore cross-exchange routing alpha in prediction markets. "
      long_input = String.duplicate(base, 10)

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(long_input)
      assert String.length(result.topic) > 0
      assert result.original_input == long_input
      assert result.domain_hints != []
      assert result.mechanism_hints != []
    end

    test "normalizes a theme with 5000+ characters" do
      base =
        "Investigate options skew patterns across fragmented sportsbook venues with arbitrage. "

      long_input = String.duplicate(base, 60)
      assert String.length(long_input) > 5000

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(long_input)
      assert result.original_input == long_input
      assert is_binary(result.topic)
    end

    test "very long input preserves original exactly" do
      long_input = String.duplicate("a", 10_000)

      assert {:ok, %Normalized{original_input: original}} = Normalizer.normalize(long_input)
      assert original == long_input
      assert String.length(original) == 10_000
    end

    test "long input with embedded whitespace anomalies" do
      chunk = "Find alpha in markets"
      # Join with varying whitespace patterns
      long_input = Enum.map_join(1..100, "   \t   ", fn _ -> chunk end)

      assert {:ok, %Normalized{normalized_text: normalized_text}} =
               Normalizer.normalize(long_input)

      refute normalized_text =~ ~r/\s{2,}/
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Deterministic invariants
  # ---------------------------------------------------------------------------
  describe "deterministic invariants" do
    test "repeated normalization returns the same result" do
      input = "Look for cross-exchange routing alpha between fragmented prediction markets"

      assert {:ok, first} = Normalizer.normalize(input)
      assert {:ok, second} = Normalizer.normalize(input)
      assert first == second
    end

    test "normalizing already normalized text does not drift" do
      input = "  Look for   cross-exchange routing alpha between fragmented prediction markets  "

      assert {:ok, first} = Normalizer.normalize(input)
      assert {:ok, second} = Normalizer.normalize(first.normalized_text)

      assert first.normalized_text == second.normalized_text
      assert first.topic == second.topic
      assert first.domain_hints == second.domain_hints
      assert first.mechanism_hints == second.mechanism_hints
      assert first.objective == second.objective
      assert first.constraints == second.constraints
    end

    test "hint ordering is stable and sorted" do
      input =
        "Routing and arbitrage across crypto prediction markets with options skew and order book data"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)

      assert Enum.map(result.domain_hints, & &1.label) == [
               "crypto",
               "options",
               "prediction-markets"
             ]

      assert Enum.map(result.mechanism_hints, & &1.label) == [
               "arbitrage",
               "order-book",
               "routing",
               "skew"
             ]
    end

    test "duplicate labels are suppressed" do
      input =
        "Prediction markets in prediction market structure with routing, routing, cross-exchange routing, and order-book order book data"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)

      assert Enum.map(result.domain_hints, & &1.label) == ["prediction-markets"]

      assert Enum.map(result.mechanism_hints, & &1.label) == [
               "cross-exchange",
               "order-book",
               "routing"
             ]
    end

    test "constraint ordering is stable and duplicate heuristic constraints are suppressed" do
      input =
        "Find alpha in prediction markets better than random selection, without proprietary data, excluding proprietary data"

      assert {:ok, %Normalized{constraints: constraints}} = Normalizer.normalize(input)

      assert [
               %Constraint{description: "random selection", kind: :methodological},
               %Constraint{description: "proprietary data", kind: :scope}
             ] = constraints
    end
  end

  # ---------------------------------------------------------------------------
  # 8. All three example themes from the objective
  # ---------------------------------------------------------------------------
  describe "objective example themes — full integration" do
    test "example 1: order-book state and prediction contracts" do
      input =
        "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)

      # original preserved
      assert result.original_input == input
      assert result.normalized_text == input

      # topic currently falls back to normalized_text
      assert result.topic == result.normalized_text

      # domains
      domain_labels = Enum.map(result.domain_hints, & &1.label)
      assert "prediction-markets" in domain_labels
      assert "options" in domain_labels

      # mechanisms
      mechanism_labels = Enum.map(result.mechanism_hints, & &1.label)
      assert "order-book" in mechanism_labels

      # objective extracted via 'help'
      assert %Objective{description: desc} = result.objective
      assert is_binary(desc)
      assert String.length(desc) > 0

      # constraint extracted via 'better than'
      assert [%Constraint{kind: :methodological} | _] = result.constraints

      # all structs are proper types
      assert Enum.all?(result.domain_hints, &match?(%DomainHint{}, &1))
      assert Enum.all?(result.mechanism_hints, &match?(%MechanismHint{}, &1))
      assert Enum.all?(result.constraints, &match?(%Constraint{}, &1))
    end

    test "example 2: cross-exchange routing alpha" do
      input = "Look for cross-exchange routing alpha between fragmented prediction markets"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)

      # original preserved
      assert result.original_input == input
      assert result.normalized_text == input

      # topic
      assert result.topic == result.normalized_text

      # domains
      domain_labels = Enum.map(result.domain_hints, & &1.label)
      assert "prediction-markets" in domain_labels

      # mechanisms
      mechanism_labels = Enum.map(result.mechanism_hints, & &1.label)
      assert "cross-exchange" in mechanism_labels
      assert "routing" in mechanism_labels

      # objective via 'look'
      assert %Objective{description: desc} = result.objective
      assert is_binary(desc)

      # no constraints
      assert result.constraints == []
    end

    test "example 3: transferable literature from options skew" do
      input = "Find transferable literature from options skew and sportsbook longshot demand"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)

      # original preserved
      assert result.original_input == input
      assert result.normalized_text == input

      # topic
      assert result.topic == result.normalized_text

      # domains
      domain_labels = Enum.map(result.domain_hints, & &1.label)
      assert "options" in domain_labels
      assert "sports-betting" in domain_labels

      # mechanisms
      mechanism_labels = Enum.map(result.mechanism_hints, & &1.label)
      assert "skew" in mechanism_labels

      # objective via 'find'
      assert %Objective{description: desc} = result.objective
      assert is_binary(desc)

      # no constraints
      assert result.constraints == []
    end
  end
end
