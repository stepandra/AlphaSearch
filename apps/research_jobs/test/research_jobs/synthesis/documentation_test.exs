defmodule ResearchJobs.SynthesisDocumentationTest do
  use ExUnit.Case, async: true

  @doc_path Path.expand("../../../../../docs/synthesis_report_builder.md", __DIR__)

  test "synthesis docs explain run semantics, citation keys, validator guarantees, and non-goals" do
    contents = File.read!(@doc_path)

    assert contents =~ "# Synthesis Report Builder"
    assert contents =~ "## What A Synthesis Run Is"
    assert contents =~ "## Snapshot To Report Flow"
    assert contents =~ "REC_0001"
    assert contents =~ "## Validator Guarantees"
    assert contents =~ "## Explicit Non-Goals"
    assert contents =~ "## Downstream Consumption"
    assert contents =~ "ResearchStore.successful_synthesis_artifact/2"
  end
end
