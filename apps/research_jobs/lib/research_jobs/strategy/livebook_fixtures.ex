defmodule ResearchJobs.Strategy.LivebookFixtures do
  @moduledoc """
  Deterministic fixture data for strategy extraction walkthrough notebooks.
  """

  alias ResearchCore.Corpus.{CanonicalRecord, SourceIdentifiers, SourceProvenanceSummary}
  alias ResearchCore.Synthesis.ValidationResult

  @spec context() :: map()
  def context do
    bundle = bundle_fixture()
    synthesis_run = synthesis_run_fixture(bundle.snapshot.id)
    artifact = artifact_fixture(bundle.snapshot.id, synthesis_run.id)

    validation_result = %ValidationResult{
      valid?: true,
      structural_errors: [],
      citation_errors: [],
      formula_errors: [],
      cited_keys: ["REC_0001", "REC_0002"],
      allowed_keys: ["REC_0001", "REC_0002"]
    }

    %{
      bundle: bundle,
      synthesis_run: synthesis_run,
      artifact: artifact,
      validation_result: validation_result
    }
  end

  @spec fake_provider_opts() :: keyword()
  def fake_provider_opts do
    [
      formula_content: formula_content(),
      strategy_content: strategy_content()
    ]
  end

  @spec formula_content() :: map()
  def formula_content do
    %{
      formulas: [
        %{
          formula_text: "score = wins / total",
          exact: true,
          partial: false,
          blocked: false,
          role: :calibration,
          source_section_ids: ["reusable_formulas"],
          supporting_citation_keys: ["REC_0001"],
          symbol_glossary: %{"score" => "calibration score"},
          notes: ["exact"]
        },
        %{
          formula_text: "liquidity penalty exists but is not disclosed",
          exact: false,
          partial: true,
          blocked: true,
          role: :execution,
          source_section_ids: ["open_gaps"],
          supporting_citation_keys: ["REC_0002"],
          notes: ["partial and blocked"]
        }
      ]
    }
  end

  @spec strategy_content() :: map()
  def strategy_content do
    %{
      strategies: [
        %{
          title: "Calibration Gate",
          thesis: "Trade only when calibration exceeds the observed threshold.",
          category: :calibration_strategy,
          candidate_kind: :directly_specified_strategy,
          market_or_domain_applicability: "prediction markets",
          direct_signal_or_rule: "enter when score > 0.62",
          entry_condition: "score > 0.62",
          exit_condition: "score < 0.55",
          formula_references: ["__FIRST_FORMULA__"],
          required_features: [
            %{name: "score_feature", description: "formula output", status: :available}
          ],
          required_datasets: [
            %{name: "market_quotes", description: "market quotes", mapping_status: :mapped}
          ],
          execution_assumptions: [
            %{kind: :execution, description: "cross at midpoint", blocking?: false}
          ],
          sizing_assumptions: [%{kind: :sizing, description: "flat size", blocking?: false}],
          evidence_references: ["REC_0001"],
          evidence_pairs: [
            %{section_id: "executive_summary", citation_key: "REC_0001"}
          ],
          conflicting_or_cautionary_evidence: ["REC_0002"],
          conflicting_evidence_pairs: [
            %{section_id: "open_gaps", citation_key: "REC_0002"}
          ],
          conflict_note: "liquidity frictions may weaken transfer",
          expected_edge_source: "miscalibration",
          validation_hints: [%{kind: :holdout, description: "test by regime", priority: :high}],
          candidate_metrics: [%{name: "hit_rate", description: "win rate", direction: :maximize}],
          falsification_idea: "Randomizing calibration should erase the edge.",
          source_section_ids: ["executive_summary", "open_gaps"],
          notes: ["direct evidence"]
        },
        %{
          title: "Narrative Only",
          thesis: "Calibration is interesting and deserves more study.",
          category: :behavioral_filter_strategy,
          candidate_kind: :speculative_not_backtestable,
          market_or_domain_applicability: "prediction markets",
          evidence_references: ["REC_0001"],
          source_section_ids: ["taxonomy_and_thematic_grouping"],
          notes: ["expected rejection"]
        }
      ]
    }
  end

  defp bundle_fixture do
    %{
      snapshot: %{
        id: "snapshot-1",
        label: "prediction-market-calibration",
        finalized_at: ~U[2026-03-30 12:00:00Z],
        normalized_theme_ids: ["theme-1"],
        branch_ids: ["branch-1"],
        retrieval_run_ids: ["retrieval-1"],
        qa_summary: %{"accepted_core" => 1, "accepted_analog" => 1}
      },
      accepted_core: [
        %CanonicalRecord{
          id: "core-1",
          canonical_title: "Calibration Under Stress",
          canonical_citation: "Calibration Under Stress (2024)",
          canonical_url: "https://example.com/core-1",
          year: 2024,
          source_type: :journal_article,
          authors: ["A. Researcher"],
          abstract: "Calibration study.",
          methodology_summary: "Measure calibration drift.",
          findings_summary: "Calibration remains stable.",
          limitations_summary: "Limited to one venue.",
          direct_product_implication: "Useful for gating.",
          classification: :accepted_core,
          formula_completeness_status: :exact,
          identifiers: %SourceIdentifiers{url: "https://example.com/core-1"},
          source_provenance_summary: %SourceProvenanceSummary{
            providers: [:serper],
            retrieval_run_ids: ["retrieval-1"],
            raw_record_ids: ["raw-core-1"],
            query_texts: ["prediction market calibration"],
            source_urls: ["https://example.com/core-1"],
            branch_kinds: [:direct],
            branch_labels: ["prediction market calibration"],
            merged_from_canonical_ids: []
          },
          evidence_strength_score: 0.91,
          relevance_score: 0.95,
          transferability_score: 0.8,
          citation_quality_score: 0.9,
          formula_actionability_score: 1.0,
          external_validity_risk: :low
        }
      ],
      accepted_analog: [
        %CanonicalRecord{
          id: "analog-1",
          canonical_title: "Liquidity Penalties in Options Markets",
          canonical_citation: "Liquidity Penalties in Options Markets (2022)",
          canonical_url: "https://example.com/analog-1",
          year: 2022,
          source_type: :working_paper,
          authors: ["B. Researcher"],
          abstract: "Analog liquidity study.",
          methodology_summary: "Measure transfer penalties.",
          findings_summary: "Liquidity costs matter.",
          limitations_summary: "Analog market only.",
          direct_product_implication: "Watch transferability.",
          classification: :accepted_analog,
          formula_completeness_status: :partial,
          identifiers: %SourceIdentifiers{url: "https://example.com/analog-1"},
          source_provenance_summary: %SourceProvenanceSummary{
            providers: [:serper],
            retrieval_run_ids: ["retrieval-1"],
            raw_record_ids: ["raw-analog-1"],
            query_texts: ["options market calibration analog"],
            source_urls: ["https://example.com/analog-1"],
            branch_kinds: [:analog],
            branch_labels: ["options market calibration analog"],
            merged_from_canonical_ids: []
          },
          evidence_strength_score: 0.58,
          relevance_score: 0.72,
          transferability_score: 0.55,
          citation_quality_score: 0.7,
          formula_actionability_score: 0.2,
          external_validity_risk: :medium
        }
      ],
      background: []
    }
  end

  defp synthesis_run_fixture(snapshot_id) do
    %{
      id: "synthesis-run-1",
      corpus_snapshot_id: snapshot_id,
      profile_id: "literature_review_v1",
      input_package: %{
        accepted_core: [
          %{
            record_id: "core-1",
            classification: :accepted_core,
            citation_key: "REC_0001",
            title: "Calibration Under Stress",
            formula: %{status: :exact, exact_reusable_formula_texts: ["score = wins / total"]},
            provenance_reference: %{
              providers: ["serper"],
              source_urls: ["https://example.com/core-1"]
            },
            scores: %{evidence_strength: 0.91}
          }
        ],
        accepted_analog: [
          %{
            record_id: "analog-1",
            classification: :accepted_analog,
            citation_key: "REC_0002",
            title: "Liquidity Penalties in Options Markets",
            formula: %{status: :partial, exact_reusable_formula_texts: []},
            provenance_reference: %{
              providers: ["serper"],
              source_urls: ["https://example.com/analog-1"]
            },
            scores: %{evidence_strength: 0.58}
          }
        ],
        background: []
      }
    }
  end

  defp artifact_fixture(snapshot_id, synthesis_run_id) do
    %{
      id: "artifact-1",
      synthesis_run_id: synthesis_run_id,
      corpus_snapshot_id: snapshot_id,
      artifact_hash: "artifact-hash-1",
      finalized_at: ~U[2026-03-30 12:30:00Z],
      cited_keys: ["REC_0001", "REC_0002"],
      content: """
      ## Executive Summary
      Calibration remains stable under stress [REC_0001].

      ## Ranked Important Papers and Findings
      1. Calibration Under Stress [REC_0001]
      2. Liquidity Penalties in Options Markets [REC_0002]

      ## Taxonomy and Thematic Grouping
      Calibration and liquidity themes [REC_0001, REC_0002].

      ## Reusable Formulas
      - score = wins / total [REC_0001]

      ## Open Gaps
      Liquidity penalty exists but is not disclosed [REC_0002].

      ## Next Prototype Recommendations
      Build a calibration gate prototype [REC_0001].
      """
    }
  end
end
