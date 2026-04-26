defmodule ResearchCore.Synthesis.PromptBuilderTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Corpus.{CanonicalRecord, SourceIdentifiers, SourceProvenanceSummary}
  alias ResearchCore.Synthesis.{InputBuilder, PromptBuilder}

  test "builds an explicit prompt spec for literature_review_v1" do
    profile = ResearchCore.Synthesis.profile!("literature_review_v1")

    bundle = %{
      snapshot: %{
        id: "snapshot-1",
        label: "prediction-market-calibration",
        finalized_at: ~U[2026-03-30 10:00:00Z],
        normalized_theme_ids: ["theme-1"],
        branch_ids: ["branch-1"],
        retrieval_run_ids: ["run-1"]
      },
      accepted_core: [record("canon-core", "Calibration Under Stress", :exact)],
      accepted_analog: [],
      background: [],
      quarantine: []
    }

    provenance = %{
      "canon-core" => %{raw_records: [%{raw_fields: %{"formula_text" => "score = wins / total"}}]}
    }

    {:ok, package} = InputBuilder.build(profile, bundle, provenance_summaries: provenance)
    request_spec = PromptBuilder.build(profile, package)

    assert request_spec.profile_id == "literature_review_v1"
    assert request_spec.output_format == :markdown

    assert request_spec.section_order == [
             "Executive Summary",
             "Ranked Important Papers and Findings",
             "Taxonomy and Thematic Grouping",
             "Reusable Formulas",
             "Open Gaps",
             "Next Prototype Recommendations",
             "Evidence Appendix",
             "Quarantine Summary"
           ]

    assert request_spec.prompt =~ "Use the exact top-level `##` headings listed below"
    assert request_spec.prompt =~ "Calibration Under Stress"
    assert request_spec.prompt =~ "REC_0001"
    assert request_spec.prompt =~ "Exact reusable formula text is available"
    assert request_spec.prompt =~ "Do not generate trading hypotheses"
  end

  test "renders citation examples from the profile key contract" do
    profile = %{
      ResearchCore.Synthesis.profile!("literature_review_v1")
      | citation_key_prefix: "SRC-",
        citation_key_width: 3
    }

    bundle = %{
      snapshot: %{
        id: "snapshot-1",
        label: "prediction-market-calibration",
        finalized_at: ~U[2026-03-30 10:00:00Z],
        normalized_theme_ids: ["theme-1"],
        branch_ids: ["branch-1"],
        retrieval_run_ids: ["run-1"]
      },
      accepted_core: [record("canon-core", "Calibration Under Stress", :exact)],
      accepted_analog: [],
      background: [],
      quarantine: []
    }

    provenance = %{
      "canon-core" => %{raw_records: [%{raw_fields: %{"formula_text" => "score = wins / total"}}]}
    }

    {:ok, package} = InputBuilder.build(profile, bundle, provenance_summaries: provenance)
    request_spec = PromptBuilder.build(profile, package)

    assert request_spec.prompt =~ "like `[SRC-001]` or `[SRC-001, SRC-002]`"
    refute request_spec.prompt =~ "like `[REC_0001]`"
  end

  defp record(id, title, formula_status) do
    %CanonicalRecord{
      id: id,
      canonical_title: title,
      canonical_citation: "Lee, Ada (2024). #{title}.",
      canonical_url: "https://example.com/#{id}",
      year: 2024,
      authors: ["Lee, Ada"],
      source_type: :journal_article,
      identifiers: %SourceIdentifiers{doi: "10.5555/#{id}"},
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
