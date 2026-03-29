defmodule ResearchCoreTest do
  use ExUnit.Case
  doctest ResearchCore

  test "greets the world" do
    assert ResearchCore.hello() == :world
  end
end
