defmodule ResearchStoreTest do
  use ExUnit.Case, async: true

  test "exposes the store entrypoints" do
    assert {:module, ResearchStore} = Code.ensure_loaded(ResearchStore)

    functions = ResearchStore.__info__(:functions)

    assert {:store_theme, 2} in functions
    assert {:store_branches, 2} in functions
    assert {:store_run, 2} in functions
    assert {:store_qa_artifacts, 3} in functions
    assert {:create_snapshot, 3} in functions
  end
end
