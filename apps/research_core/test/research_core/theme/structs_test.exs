defmodule ResearchCore.Theme.StructsTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Theme.Raw
  alias ResearchCore.Theme.Normalized
  alias ResearchCore.Theme.Objective
  alias ResearchCore.Theme.Constraint
  alias ResearchCore.Theme.DomainHint
  alias ResearchCore.Theme.MechanismHint

  describe "Raw struct instantiation with defaults" do
    test "creates with only raw_text, optional fields default to nil" do
      raw = %Raw{raw_text: "Find alpha in prediction markets"}

      assert %Raw{
               raw_text: "Find alpha in prediction markets",
               source: nil,
               inserted_at: nil,
               updated_at: nil
             } = raw
    end

    test "creates with all fields populated" do
      now = DateTime.utc_now()

      raw = %Raw{
        raw_text: "Cross-exchange routing alpha",
        source: "manual-entry",
        inserted_at: now,
        updated_at: now
      }

      assert raw.raw_text == "Cross-exchange routing alpha"
      assert raw.source == "manual-entry"
      assert raw.inserted_at == now
    end

    test "rejects creation without raw_text via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(Raw, %{source: "test"})
      end
    end
  end

  describe "Normalized struct instantiation with all fields" do
    test "creates with required fields only, lists default to empty" do
      normalized = %Normalized{
        original_input: "Can order-book state help recalibrate OTM contracts?",
        normalized_text: "Can order-book state help recalibrate OTM contracts?",
        topic: "order-book recalibration"
      }

      assert %Normalized{
               original_input: "Can order-book state help recalibrate OTM contracts?",
               normalized_text: "Can order-book state help recalibrate OTM contracts?",
               topic: "order-book recalibration",
               domain_hints: [],
               mechanism_hints: [],
               constraints: [],
               objective: nil,
               notes: nil
             } = normalized
    end

    test "creates with all fields populated" do
      normalized = %Normalized{
        original_input: "Can order-book state help recalibrate cheap OTM prediction contracts?",
        normalized_text: "Can order-book state help recalibrate cheap OTM prediction contracts?",
        topic: "OTM prediction contract recalibration",
        domain_hints: [
          %DomainHint{label: "prediction-markets"},
          %DomainHint{label: "options-pricing"}
        ],
        mechanism_hints: [
          %MechanismHint{label: "order-book-state"}
        ],
        objective: %Objective{description: "Recalibrate cheap OTM contracts"},
        constraints: [
          %Constraint{description: "No external APIs", kind: :technical},
          %Constraint{description: "Focus on liquid markets", kind: :scope}
        ],
        notes: "Originated from order-book research thread"
      }

      assert normalized.topic == "OTM prediction contract recalibration"

      assert normalized.normalized_text ==
               "Can order-book state help recalibrate cheap OTM prediction contracts?"

      assert length(normalized.domain_hints) == 2
      assert length(normalized.mechanism_hints) == 1
      assert length(normalized.constraints) == 2
      assert %Objective{} = normalized.objective
      assert normalized.notes == "Originated from order-book research thread"
    end

    test "rejects creation without topic via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(Normalized, %{original_input: "some input", normalized_text: "some input"})
      end
    end

    test "rejects creation without original_input via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(Normalized, %{normalized_text: "some topic", topic: "some topic"})
      end
    end

    test "rejects creation without normalized_text via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(Normalized, %{original_input: "some input", topic: "some topic"})
      end
    end
  end

  describe "supporting struct instantiation" do
    test "Objective requires description" do
      obj = %Objective{description: "Discover pricing inefficiencies"}
      assert obj.description == "Discover pricing inefficiencies"

      assert_raise ArgumentError, fn ->
        struct!(Objective, %{})
      end
    end

    test "Constraint requires description, kind is optional" do
      constraint = %Constraint{description: "Time-bounded to 2024 data"}
      assert constraint.description == "Time-bounded to 2024 data"
      assert constraint.kind == nil

      constraint_with_kind = %Constraint{
        description: "Only public datasets",
        kind: :methodological
      }

      assert constraint_with_kind.kind == :methodological
    end

    test "Constraint accepts custom atom kinds" do
      constraint = %Constraint{description: "Budget cap", kind: :financial}
      assert constraint.kind == :financial
    end

    test "DomainHint requires label" do
      hint = %DomainHint{label: "sports-betting"}
      assert hint.label == "sports-betting"

      assert_raise ArgumentError, fn ->
        struct!(DomainHint, %{})
      end
    end

    test "MechanismHint requires label" do
      hint = %MechanismHint{label: "cross-exchange-routing"}
      assert hint.label == "cross-exchange-routing"

      assert_raise ArgumentError, fn ->
        struct!(MechanismHint, %{})
      end
    end
  end

  describe "pattern matching on struct fields" do
    test "matches Raw struct on raw_text" do
      raw = %Raw{raw_text: "Find transferable literature from options skew"}

      assert %Raw{raw_text: "Find transferable literature from options skew"} = raw
    end

    test "matches Normalized struct on topic and nested structs" do
      normalized = %Normalized{
        original_input: "Look for cross-exchange routing alpha",
        normalized_text: "Look for cross-exchange routing alpha",
        topic: "cross-exchange alpha",
        domain_hints: [%DomainHint{label: "prediction-markets"}],
        mechanism_hints: [%MechanismHint{label: "cross-exchange-routing"}],
        objective: %Objective{description: "Find routing alpha"}
      }

      assert %Normalized{
               topic: "cross-exchange alpha",
               domain_hints: [%DomainHint{label: "prediction-markets"}],
               mechanism_hints: [%MechanismHint{label: "cross-exchange-routing"}],
               objective: %Objective{description: "Find routing alpha"}
             } = normalized
    end

    test "destructures Normalized in function head style" do
      normalized = %Normalized{
        original_input: "Find transferable literature from options skew",
        normalized_text: "Find transferable literature from options skew",
        topic: "skew analysis",
        domain_hints: [%DomainHint{label: "options-pricing"}],
        constraints: [%Constraint{description: "Academic sources only", kind: :scope}]
      }

      %Normalized{topic: topic, constraints: [%Constraint{kind: kind} | _]} = normalized

      assert topic == "skew analysis"
      assert kind == :scope
    end

    test "matches on empty lists in Normalized defaults" do
      normalized = %Normalized{
        original_input: "bare",
        normalized_text: "bare",
        topic: "bare topic"
      }

      assert %Normalized{domain_hints: [], mechanism_hints: [], constraints: []} = normalized
    end

    test "matches Constraint with specific kind atom" do
      constraints = [
        %Constraint{description: "No paid APIs", kind: :technical},
        %Constraint{description: "2024 only", kind: :temporal},
        %Constraint{description: "Public data", kind: :scope}
      ]

      technical = Enum.filter(constraints, &match?(%Constraint{kind: :technical}, &1))
      assert [%Constraint{description: "No paid APIs"}] = technical
    end

    test "matches multiple domain hints via pattern" do
      normalized = %Normalized{
        original_input: "multi-domain input",
        normalized_text: "multi-domain input",
        topic: "multi-domain",
        domain_hints: [
          %DomainHint{label: "prediction-markets"},
          %DomainHint{label: "sports-betting"}
        ]
      }

      assert %Normalized{
               domain_hints: [
                 %DomainHint{label: "prediction-markets"},
                 %DomainHint{label: "sports-betting"}
               ]
             } = normalized
    end
  end
end
