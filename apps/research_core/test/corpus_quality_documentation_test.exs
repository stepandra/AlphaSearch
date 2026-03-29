defmodule ResearchCore.CorpusQualityDocumentationTest do
  use ExUnit.Case, async: true

  @doc_path Path.expand("../../../docs/corpus_quality.md", __DIR__)

  test "corpus QA doc covers stages buckets guarantees and non-goals" do
    assert File.exists?(@doc_path)

    contents = File.read!(@doc_path)

    assert contents =~ "# Corpus Quality Gate"
    assert contents =~ "## Pipeline Stages"
    assert contents =~ "canonicalize"
    assert contents =~ "group_duplicates"
    assert contents =~ "conflated raw records"
    assert contents =~ "classification"

    assert contents =~ "## Classification Buckets"
    assert contents =~ "accepted_core"
    assert contents =~ "accepted_analog"
    assert contents =~ "background"
    assert contents =~ "quarantine"
    assert contents =~ "discard"

    assert contents =~ "## Guarantees"
    assert contents =~ "duplicate groups"
    assert contents =~ "audit trail"
    assert contents =~ "formula completeness"

    assert contents =~ "## Non-Goals"
    assert contents =~ "knowledge graph"
    assert contents =~ "hypothesis extraction"
    assert contents =~ "backtests"

    assert contents =~ "## Example Output"
    assert contents =~ "QAResult"
    assert contents =~ "DuplicateGroup"
    assert contents =~ "QuarantineRecord"
  end
end
