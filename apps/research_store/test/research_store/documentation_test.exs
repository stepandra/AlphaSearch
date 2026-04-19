defmodule ResearchStore.DocumentationTest do
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../README.md", __DIR__)
  @doc_path Path.expand("../../../../docs/evidence_store_registry.md", __DIR__)

  test "store docs explain the snapshot model and non-goals" do
    assert File.read!(@readme_path) =~ "corpus_snapshot"
    assert File.read!(@readme_path) =~ "Stable Identifiers"

    contents = File.read!(@doc_path)

    assert contents =~ "# Evidence Store Registry"
    assert contents =~ "## Persistence Model"
    assert contents =~ "## Corpus Snapshot / Evidence Bundle"
    assert contents =~ "append-only artifacts"
    assert contents =~ "ResearchStore.CorpusRegistry.provenance_summary/1"
    assert contents =~ "Explicit Non-Goals"
  end
end
