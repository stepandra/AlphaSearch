defmodule ResearchCore.Theme.MechanismHintTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Theme.MechanismHint

  describe "struct definition" do
    test "creates with label" do
      hint = %MechanismHint{label: "order-book-state"}

      assert hint.label == "order-book-state"
    end

    test "enforces label as a required key" do
      assert_raise ArgumentError, fn ->
        struct!(MechanismHint, %{})
      end
    end
  end
end
