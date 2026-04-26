defmodule ResearchCore.CanonicalTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Canonical

  test "hash is stable for logically equivalent maps with different insertion order" do
    left = %{phase: :strategy, payload: %{b: 2, a: 1}, flags: [true, nil, :exact]}

    right =
      Map.new([{:flags, [true, nil, :exact]}, {:payload, %{a: 1, b: 2}}, {:phase, :strategy}])

    assert Canonical.hash(left) == Canonical.hash(right)
  end

  test "encoding includes a schema version envelope" do
    assert %{
             "schema_version" => "research_core.canonical.v1",
             "value" => %{"phase" => "formula_extraction"}
           } = Canonical.encode!(%{phase: :formula_extraction}) |> Jason.decode!()
  end

  test "encoding sorts nested map keys in the emitted JSON" do
    assert Canonical.encode!(%{z: 1, a: %{b: 2, a: 1}}) ==
             ~s({"schema_version":"research_core.canonical.v1","value":{"a":{"a":1,"b":2},"z":1}})
  end

  test "encoding rejects normalized key collisions" do
    assert_raise Jason.EncodeError, ~r/duplicate key: phase/, fn ->
      Canonical.encode!(%{:phase => :formula, "phase" => :strategy})
    end
  end
end
