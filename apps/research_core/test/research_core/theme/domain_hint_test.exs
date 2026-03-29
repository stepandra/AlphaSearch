defmodule ResearchCore.Theme.DomainHintTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Theme.DomainHint

  describe "struct definition" do
    test "creates with label" do
      hint = %DomainHint{label: "prediction-markets"}

      assert hint.label == "prediction-markets"
    end

    test "enforces label as a required key" do
      assert_raise ArgumentError, fn ->
        struct!(DomainHint, %{})
      end
    end
  end
end
