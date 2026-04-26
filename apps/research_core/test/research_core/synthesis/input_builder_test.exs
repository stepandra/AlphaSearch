defmodule ResearchCore.Synthesis.InputBuilderTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Corpus.{
    AcceptanceDecision,
    CanonicalRecord,
    QuarantineRecord,
    SourceIdentifiers,
    SourceProvenanceSummary
  }

  alias ResearchCore.Canonical
  alias ResearchCore.Synthesis.{InputBuilder, InputPackage}

  test "builds a deterministic package with stable citation keys and provenance references" do
    profile = ResearchCore.Synthesis.profile!("literature_review_v1")
    bundle = snapshot_bundle()
    provenance = provenance_summaries()

    assert {:ok, %InputPackage{} = package_one} =
             InputBuilder.build(profile, bundle,
               include_background?: true,
               provenance_summaries: provenance
             )

    assert {:ok, %InputPackage{} = package_two} =
             InputBuilder.build(profile, bundle,
               include_background?: true,
               provenance_summaries: provenance
             )

    assert package_one.digest == package_two.digest
    assert package_one.digest == Canonical.hash(%{package_one | digest: "pending"})
    assert Enum.map(package_one.citation_keys, & &1.key) == ["REC_0001", "REC_0002", "REC_0003"]
    assert Enum.map(package_one.accepted_core, & &1.citation_key) == ["REC_0001"]
    assert Enum.map(package_one.accepted_analog, & &1.citation_key) == ["REC_0002"]
    assert Enum.map(package_one.background, & &1.citation_key) == ["REC_0003"]

    assert package_one.accepted_core
           |> hd()
           |> Map.fetch!(:formula)
           |> Map.fetch!(:exact_reusable_formula_texts) == ["score = wins / total"]

    assert package_one.excluded_inputs |> Enum.member?("raw retrieval noise")

    assert package_one.provenance_references["canon-core"].branch_labels == [
             "prediction market calibration"
           ]
  end

  test "only includes quarantine metadata when explicitly requested" do
    profile = ResearchCore.Synthesis.profile!("literature_review_v1")
    bundle = snapshot_bundle()

    assert {:ok, package_without_quarantine} = InputBuilder.build(profile, bundle)
    assert package_without_quarantine.quarantine_summary == []

    assert {:ok, package_with_quarantine} =
             InputBuilder.build(profile, bundle,
               include_quarantine_summary?: true,
               provenance_summaries: provenance_summaries()
             )

    assert [%{id: "quarantine-1", reason_codes: [:missing_year]}] =
             package_with_quarantine.quarantine_summary
  end

  defp snapshot_bundle do
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
      background: [record("canon-background", "Venue Documentation", :background, :none)],
      quarantine: [quarantine_record()]
    }
  end

  defp provenance_summaries do
    %{
      "canon-core" => %{
        raw_records: [
          %{id: "raw-core-1", raw_fields: %{"formula_text" => "score = wins / total"}}
        ],
        decisions: [%{reason_codes: [:accepted]}]
      },
      "canon-analog" => %{
        raw_records: [
          %{id: "raw-analog-1", raw_fields: %{}}
        ],
        decisions: [%{reason_codes: [:analog_support]}]
      },
      "canon-background" => %{
        raw_records: [
          %{id: "raw-background-1", raw_fields: %{}}
        ],
        decisions: [%{reason_codes: [:background_only]}]
      }
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
      abstract: "Useful evidence.",
      methodology_summary: "Empirical study.",
      findings_summary: "Important finding.",
      limitations_summary: "Small sample.",
      direct_product_implication: "Relevant to calibration design.",
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
      },
      raw_record_ids: ["raw-#{id}"],
      relevance_score: 5,
      evidence_strength_score: 4,
      transferability_score: 3,
      citation_quality_score: 5,
      formula_actionability_score: 4
    }
  end

  defp quarantine_record do
    %QuarantineRecord{
      id: "quarantine-1",
      raw_record_ids: ["raw-quarantine-1"],
      reason_codes: [:missing_year],
      decision: %AcceptanceDecision{
        record_id: "raw-quarantine-1",
        stage: :classification,
        action: :quarantined
      },
      candidate_records: []
    }
  end
end
