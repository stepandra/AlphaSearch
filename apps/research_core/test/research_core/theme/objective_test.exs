defmodule ResearchCore.Theme.ObjectiveTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Theme.Objective

  describe "struct definition" do
    test "creates with description" do
      obj = %Objective{description: "Recalibrate OTM prediction contracts"}

      assert obj.description == "Recalibrate OTM prediction contracts"
    end

    test "enforces description as a required key" do
      assert_raise ArgumentError, fn ->
        struct!(Objective, %{})
      end
    end
  end
end
