defmodule ResearchCore.Theme.NormalizedTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Theme.Normalized
  alias ResearchCore.Theme.Objective
  alias ResearchCore.Theme.Constraint
  alias ResearchCore.Theme.DomainHint
  alias ResearchCore.Theme.MechanismHint

  describe "struct definition" do
    test "creates with all fields" do
      normalized = %Normalized{
        original_input: "Can order-book state help recalibrate cheap OTM prediction contracts?",
        normalized_text: "Can order-book state help recalibrate cheap OTM prediction contracts?",
        topic: "OTM prediction contract recalibration",
        domain_hints: [%DomainHint{label: "prediction-markets"}],
        mechanism_hints: [%MechanismHint{label: "order-book-state"}],
        objective: %Objective{description: "Recalibrate cheap OTM contracts"},
        constraints: [%Constraint{description: "No external APIs", kind: :technical}],
        notes: "Originated from order-book research thread"
      }

      assert normalized.topic == "OTM prediction contract recalibration"

      assert normalized.normalized_text ==
               "Can order-book state help recalibrate cheap OTM prediction contracts?"

      assert [%DomainHint{label: "prediction-markets"}] = normalized.domain_hints
      assert [%MechanismHint{label: "order-book-state"}] = normalized.mechanism_hints
      assert %Objective{description: "Recalibrate cheap OTM contracts"} = normalized.objective

      assert [%Constraint{description: "No external APIs", kind: :technical}] =
               normalized.constraints

      assert normalized.notes == "Originated from order-book research thread"

      assert normalized.original_input ==
               "Can order-book state help recalibrate cheap OTM prediction contracts?"
    end

    test "enforces original_input, normalized_text, and topic as required keys" do
      assert_raise ArgumentError, fn ->
        struct!(Normalized, %{})
      end
    end

    test "defaults list fields to empty lists" do
      normalized = %Normalized{
        original_input: "test input",
        normalized_text: "test input",
        topic: "test"
      }

      assert normalized.domain_hints == []
      assert normalized.mechanism_hints == []
      assert normalized.constraints == []
      assert normalized.objective == nil
      assert normalized.notes == nil
    end
  end
end
