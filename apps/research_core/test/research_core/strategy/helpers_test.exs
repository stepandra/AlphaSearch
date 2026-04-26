defmodule ResearchCore.Strategy.HelpersTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Strategy.Helpers

  test "extracts default REC citations" do
    assert Helpers.extract_cited_keys("See [REC_0002, REC_0001] and REC_0002.") == [
             "REC_0001",
             "REC_0002"
           ]
  end

  test "extracts citations using an explicit profile key contract" do
    assert Helpers.extract_cited_keys("See [SRC-001, SRC-999] and REC_0001.", "SRC-", 3) == [
             "SRC-001",
             "SRC-999"
           ]
  end
end
