defmodule ResearchJobs.Livebook.PipelineTest do
  use ExUnit.Case, async: true

  alias ResearchJobs.Livebook.Pipeline
  alias ResearchJobs.Livebook.PipelineFixtures

  test "runtime helper starts req-backed notebook dependencies without booting app supervision trees" do
    assert [%{app: :req, status: :ok, started: started}] = Pipeline.ensure_runtime_apps_started()
    assert is_list(started)
  end

  test "fixture helpers expose inspectable theme, query, raw-record, and qa stages" do
    context = PipelineFixtures.context()

    assert context.theme_input == "prediction market calibration under stress"
    assert context.normalized_theme.topic == context.theme_input

    assert Enum.any?(context.query_rows, fn row ->
             row.branch_kind == :direct and is_binary(row.query_text) and row.query_text != ""
           end)

    assert Enum.any?(context.raw_records, fn raw_record ->
             raw_record.raw_fields[:formula_text] ==
               "We estimate calibration drift by regime and report score = wins / total as the operational metric."
           end)

    assert ["Prediction Market Calibration Under Stress"] ==
             Enum.map(context.qa_result.accepted_core, & &1.canonical_title)

    assert ["Options Market Calibration for Thin Liquidity"] ==
             Enum.map(context.qa_result.accepted_analog, & &1.canonical_title)

    assert context.bundle.snapshot.id == "snapshot_livebook_fixture"
    assert context.bundle.snapshot.normalized_theme_ids == ["theme_livebook_fixture"]
    assert context.bundle.snapshot.retrieval_run_ids == ["retrieval_fixture_001"]
  end
end
