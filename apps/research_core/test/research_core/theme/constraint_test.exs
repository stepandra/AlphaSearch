defmodule ResearchCore.Theme.ConstraintTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Theme.Constraint

  describe "struct definition" do
    test "creates with description and kind" do
      constraint = %Constraint{description: "No external API calls", kind: :technical}

      assert constraint.description == "No external API calls"
      assert constraint.kind == :technical
    end

    test "enforces description as a required key" do
      assert_raise ArgumentError, fn ->
        struct!(Constraint, %{})
      end
    end

    test "defaults kind to nil" do
      constraint = %Constraint{description: "Budget limit"}

      assert constraint.kind == nil
    end
  end
end
