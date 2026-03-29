defmodule ResearchCore.Theme.NormalizerTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Theme.Normalizer
  alias ResearchCore.Theme.{Normalized, Objective, Constraint, DomainHint, MechanismHint}

  describe "normalize/1 validation" do
    test "returns {:error, :empty_input} for empty string" do
      assert {:error, :empty_input} = Normalizer.normalize("")
    end

    test "returns {:error, :whitespace_only} for whitespace-only input" do
      assert {:error, :whitespace_only} = Normalizer.normalize("   ")
    end

    test "returns {:error, :whitespace_only} for tabs and newlines only" do
      assert {:error, :whitespace_only} = Normalizer.normalize("\t\n  \r\n")
    end

    test "returns {:error, :empty_input} for nil" do
      assert {:error, :empty_input} = Normalizer.normalize(nil)
    end

    test "returns {:error, :invalid_input_type} for non-binary input" do
      assert {:error, :invalid_input_type} = Normalizer.normalize(42)
      assert {:error, :invalid_input_type} = Normalizer.normalize(:atom_input)
      assert {:error, :invalid_input_type} = Normalizer.normalize(["list"])
    end
  end

  describe "normalize/1 text cleaning" do
    test "trims leading and trailing whitespace" do
      assert {:ok, %Normalized{original_input: original, normalized_text: normalized_text}} =
               Normalizer.normalize("  some theme  ")

      assert original == "  some theme  "
      refute String.starts_with?(normalized_text, " ")
      refute String.ends_with?(normalized_text, " ")
    end

    test "collapses duplicate whitespace in normalized_text" do
      assert {:ok, %Normalized{normalized_text: normalized_text}} =
               Normalizer.normalize("find   alpha   in   markets")

      refute normalized_text =~ ~r/\s{2,}/
    end

    test "preserves original input verbatim" do
      raw = "  Can   order-book   state help?  "

      assert {:ok, %Normalized{original_input: ^raw}} = Normalizer.normalize(raw)
    end
  end

  describe "normalize/1 topic contract" do
    test "topic currently falls back to normalized_text" do
      input =
        "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?"

      assert {:ok, %Normalized{normalized_text: normalized_text, topic: topic}} =
               Normalizer.normalize(input)

      assert topic == normalized_text
    end
  end

  describe "normalize/1 domain hint extraction" do
    test "identifies prediction markets domain" do
      input =
        "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?"

      assert {:ok, %Normalized{domain_hints: hints}} = Normalizer.normalize(input)
      labels = Enum.map(hints, & &1.label)
      assert "prediction-markets" in labels
    end

    test "identifies options domain" do
      input = "Find transferable literature from options skew and sportsbook longshot demand"

      assert {:ok, %Normalized{domain_hints: hints}} = Normalizer.normalize(input)
      labels = Enum.map(hints, & &1.label)
      assert "options" in labels
    end

    test "identifies sports betting domain" do
      input = "Find transferable literature from options skew and sportsbook longshot demand"

      assert {:ok, %Normalized{domain_hints: hints}} = Normalizer.normalize(input)
      labels = Enum.map(hints, & &1.label)
      assert "sports-betting" in labels
    end

    test "identifies multiple domains" do
      input = "Find transferable literature from options skew and sportsbook longshot demand"

      assert {:ok, %Normalized{domain_hints: hints}} = Normalizer.normalize(input)
      assert length(hints) >= 2
    end

    test "returns empty domain hints when no domain detected" do
      input = "Explore general patterns in data analysis"

      assert {:ok, %Normalized{domain_hints: []}} = Normalizer.normalize(input)
    end

    test "domain hints are DomainHint structs" do
      input = "Look for cross-exchange routing alpha between fragmented prediction markets"

      assert {:ok, %Normalized{domain_hints: [%DomainHint{} | _]}} = Normalizer.normalize(input)
    end
  end

  describe "normalize/1 mechanism hint extraction" do
    test "identifies order book mechanism" do
      input =
        "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?"

      assert {:ok, %Normalized{mechanism_hints: hints}} = Normalizer.normalize(input)
      labels = Enum.map(hints, & &1.label)
      assert "order-book" in labels
    end

    test "identifies routing mechanism" do
      input = "Look for cross-exchange routing alpha between fragmented prediction markets"

      assert {:ok, %Normalized{mechanism_hints: hints}} = Normalizer.normalize(input)
      labels = Enum.map(hints, & &1.label)
      assert "routing" in labels
    end

    test "identifies skew mechanism" do
      input = "Find transferable literature from options skew and sportsbook longshot demand"

      assert {:ok, %Normalized{mechanism_hints: hints}} = Normalizer.normalize(input)
      labels = Enum.map(hints, & &1.label)
      assert "skew" in labels
    end

    test "returns empty mechanism hints when none detected" do
      input = "Explore general patterns in data analysis"

      assert {:ok, %Normalized{mechanism_hints: []}} = Normalizer.normalize(input)
    end

    test "mechanism hints are MechanismHint structs" do
      input = "Can order-book state help recalibrate cheap OTM prediction contracts?"

      assert {:ok, %Normalized{mechanism_hints: [%MechanismHint{} | _]}} =
               Normalizer.normalize(input)
    end
  end

  describe "normalize/1 objective extraction" do
    test "extracts objective signaled by keywords like 'help', 'find', 'look for'" do
      input =
        "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?"

      assert {:ok, %Normalized{objective: %Objective{description: desc}}} =
               Normalizer.normalize(input)

      assert is_binary(desc)
      assert String.length(desc) > 0
    end

    test "returns nil objective when no objective keyword detected" do
      input = "General exploration of prediction market microstructure"

      assert {:ok, %Normalized{objective: nil}} = Normalizer.normalize(input)
    end
  end

  describe "normalize/1 constraint extraction" do
    test "extracts heuristic constraints signaled by 'better than', 'without', 'only'" do
      input =
        "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?"

      assert {:ok, %Normalized{constraints: constraints}} = Normalizer.normalize(input)
      assert [%Constraint{} | _] = constraints
    end

    test "returns empty constraints when none detected" do
      input = "Look for cross-exchange routing alpha between fragmented prediction markets"

      assert {:ok, %Normalized{constraints: []}} = Normalizer.normalize(input)
    end
  end

  describe "normalize/1 acceptance test" do
    test "full normalization of primary example theme" do
      input =
        "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?"

      assert {:ok, %Normalized{} = result} = Normalizer.normalize(input)

      # Preserves original
      assert result.original_input == input
      assert result.normalized_text == input

      # Topic currently falls back to normalized_text
      assert result.topic == result.normalized_text

      # Detected domain
      domain_labels = Enum.map(result.domain_hints, & &1.label)
      assert "prediction-markets" in domain_labels

      # Detected mechanism
      mechanism_labels = Enum.map(result.mechanism_hints, & &1.label)
      assert "order-book" in mechanism_labels

      # Has objective
      assert %Objective{} = result.objective

      # Has constraint (better than price alone)
      assert length(result.constraints) >= 1
    end
  end
end
