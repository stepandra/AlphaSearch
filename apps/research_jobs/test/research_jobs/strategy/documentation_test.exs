defmodule ResearchJobs.StrategyDocumentationTest do
  use ExUnit.Case, async: true

  @doc_path Path.expand("../../../../../docs/strategy_spec_builder.md", __DIR__)

  test "strategy docs explain specs, formulas, readiness, linkage, and non-goals" do
    contents = File.read!(@doc_path)

    assert contents =~ "# Strategy Spec Builder"
    assert contents =~ "## What A Strategy Spec Is"
    assert contents =~ "## How It Differs From Synthesis Text"
    assert contents =~ "## Formula Representation"
    assert contents =~ "## Backtest Ready Vs Blocked"
    assert contents =~ "## Evidence Linkage"
    assert contents =~ "## Explicit Non-Goals"
    assert contents =~ "ResearchStore.ready_strategy_specs_for_snapshot/2"
  end
end
