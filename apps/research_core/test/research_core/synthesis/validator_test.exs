defmodule ResearchCore.Synthesis.ValidatorTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Corpus.{CanonicalRecord, SourceIdentifiers, SourceProvenanceSummary}
  alias ResearchCore.Synthesis.{InputBuilder, Validator}

  test "accepts a well-structured markdown report with valid citations" do
    profile = ResearchCore.Synthesis.profile!("literature_review_v1")
    {:ok, package} = InputBuilder.build(profile, bundle(), provenance_summaries: provenance())

    report = """
    ## Executive Summary
    Calibration improves under stress [REC_0001].

    ## Ranked Important Papers and Findings
    1. Calibration Under Stress [REC_0001]

    ## Taxonomy and Thematic Grouping
    Direct evidence [REC_0001]. Analog evidence [REC_0002].

    ## Reusable Formulas
    - score = wins / total [REC_0001]
    - Exact formula text unavailable [REC_0002]

    ## Open Gaps
    Venue coverage is still thin [REC_0001, REC_0002].

    ## Next Prototype Recommendations
    Build a calibration dashboard prototype [REC_0001].

    ## Evidence Appendix
    - REC_0001 Calibration Under Stress
    - REC_0002 Options Market Analog
    """

    result = Validator.validate(profile, package, report)

    assert result.valid?
    assert result.structural_errors == []
    assert result.citation_errors == []
    assert result.formula_errors == []
    assert result.cited_keys == ["REC_0001", "REC_0002"]
  end

  test "rejects unknown citations and out-of-order sections" do
    profile = ResearchCore.Synthesis.profile!("literature_review_v1")
    {:ok, package} = InputBuilder.build(profile, bundle(), provenance_summaries: provenance())

    report = """
    ## Ranked Important Papers and Findings
    Important [REC_9999].

    ## Executive Summary
    Summary [REC_0001].
    """

    result = Validator.validate(profile, package, report)

    refute result.valid?
    assert Enum.any?(result.structural_errors, &(&1.type == :missing_required_section))
    assert Enum.any?(result.structural_errors, &(&1.type == :section_order_violation))
    assert [%{type: :unknown_citation_key}] = result.citation_errors
  end

  test "rejects formula-like text for records without exact formulas" do
    profile = ResearchCore.Synthesis.profile!("literature_review_v1")
    {:ok, package} = InputBuilder.build(profile, bundle(), provenance_summaries: provenance())

    report = """
    ## Executive Summary
    Summary [REC_0001].

    ## Ranked Important Papers and Findings
    Important [REC_0001].

    ## Taxonomy and Thematic Grouping
    Grouping [REC_0001].

    ## Reusable Formulas
    - edge = payoff / variance [REC_0002]

    ## Open Gaps
    Gap [REC_0001].

    ## Next Prototype Recommendations
    Prototype [REC_0001].

    ## Evidence Appendix
    Appendix [REC_0001].
    """

    result = Validator.validate(profile, package, report)

    refute result.valid?
    assert [%{type: :non_exact_formula_reference}] = result.formula_errors
  end

  defp bundle do
    %{
      snapshot: %{
        id: "snapshot-1",
        label: "prediction-market-calibration",
        finalized_at: ~U[2026-03-30 10:00:00Z],
        normalized_theme_ids: ["theme-1"],
        branch_ids: ["branch-1"],
        retrieval_run_ids: ["run-1"]
      },
      accepted_core: [record("canon-core", "Calibration Under Stress", :accepted_core, :exact)],
      accepted_analog: [
        record("canon-analog", "Options Market Analog", :accepted_analog, :partial)
      ],
      background: [],
      quarantine: []
    }
  end

  defp provenance do
    %{
      "canon-core" => %{raw_records: [%{raw_fields: %{"formula_text" => "score = wins / total"}}]},
      "canon-analog" => %{raw_records: [%{raw_fields: %{}}]}
    }
  end

  defp record(id, title, classification, formula_status) do
    %CanonicalRecord{
      id: id,
      canonical_title: title,
      canonical_citation: "Lee, Ada (2024). #{title}.",
      canonical_url: "https://example.com/#{id}",
      year: 2024,
      authors: ["Lee, Ada"],
      source_type: :journal_article,
      identifiers: %SourceIdentifiers{doi: "10.5555/#{id}"},
      classification: classification,
      formula_completeness_status: formula_status,
      source_provenance_summary: %SourceProvenanceSummary{
        providers: [:serper],
        retrieval_run_ids: ["run-1"],
        raw_record_ids: ["raw-#{id}"],
        query_texts: ["prediction market calibration"],
        source_urls: ["https://example.com/#{id}"],
        branch_kinds: [:direct],
        branch_labels: ["prediction market calibration"],
        merged_from_canonical_ids: []
      }
    }
  end
end
