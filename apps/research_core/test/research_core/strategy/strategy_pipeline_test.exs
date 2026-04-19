defmodule ResearchCore.Strategy.StrategyPipelineTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ResearchCore.Corpus.{CanonicalRecord, SourceIdentifiers, SourceProvenanceSummary}
  alias ResearchCore.Strategy

  alias ResearchCore.Strategy.{
    CandidateNormalizer,
    DuplicateSuppressor,
    FormulaNormalizer,
    InputBuilder
  }

  alias ResearchCore.Synthesis.ValidationResult

  test "builds an extraction input package only from a validated synthesis artifact" do
    bundle = bundle_fixture()
    synthesis_run = synthesis_run_fixture(bundle.snapshot.id)
    artifact = artifact_fixture(bundle.snapshot.id, synthesis_run.id)

    validation = %ValidationResult{
      valid?: true,
      structural_errors: [],
      citation_errors: [],
      formula_errors: [],
      cited_keys: ["REC_0001"],
      allowed_keys: ["REC_0001"]
    }

    assert {:ok, package} = InputBuilder.build(bundle, synthesis_run, artifact, validation)
    assert package.corpus_snapshot_id == bundle.snapshot.id
    assert package.synthesis_artifact_id == artifact.id
    assert Map.has_key?(package.section_lookup, :executive_summary)
    assert package.record_formula_availability["REC_0001"].status == :exact
    assert Map.keys(package.resolved_records) == ["REC_0001", "REC_0002"]
  end

  test "resolves strategy input records from the snapshot even when synthesis input metadata diverges" do
    bundle = bundle_fixture()

    synthesis_run =
      bundle.snapshot.id
      |> synthesis_run_fixture()
      |> update_in([:input_package, :accepted_core, Access.at(0)], fn record ->
        record
        |> Map.put(:citation_key, "REC_9999")
        |> Map.put(:scores, %{evidence_strength: 0.01})
      end)

    artifact = artifact_fixture(bundle.snapshot.id, synthesis_run.id)

    validation = %ValidationResult{
      valid?: true,
      structural_errors: [],
      citation_errors: [],
      formula_errors: [],
      cited_keys: ["REC_0001", "REC_0002"],
      allowed_keys: ["REC_0001", "REC_0002"]
    }

    assert {:ok, package} = InputBuilder.build(bundle, synthesis_run, artifact, validation)
    assert package.resolved_records["REC_0001"].record_id == "core-1"
    assert package.resolved_records["REC_0001"].scores.evidence_strength == 0.91

    assert package.resolved_records["REC_0001"].provenance_reference.raw_record_ids == [
             "raw-core-1"
           ]
  end

  test "normalizes exact and partial formulas, preserves evidence links, and rejects unknown citations" do
    package = input_package_fixture()

    result =
      FormulaNormalizer.normalize(package, [
        %{
          formula_text: "score = wins / total",
          exact?: true,
          partial?: false,
          blocked?: false,
          role: :calibration,
          source_section_ids: ["reusable_formulas"],
          supporting_citation_keys: ["REC_0001"],
          symbol_glossary: %{"score" => "calibration score"}
        },
        %{
          formula_text: "liquidity penalty exists but is not disclosed",
          exact?: false,
          partial?: true,
          blocked?: true,
          role: :execution,
          source_section_ids: ["open_gaps"],
          supporting_citation_keys: ["REC_0002"]
        },
        %{
          formula_text: "phantom = alpha / beta",
          exact?: true,
          partial?: false,
          blocked?: false,
          role: :other,
          source_section_ids: ["reusable_formulas"],
          supporting_citation_keys: ["REC_9999"]
        }
      ])

    assert [exact_formula, partial_formula] = result.accepted
    assert exact_formula.exact?
    assert partial_formula.partial?
    assert partial_formula.blocked?
    assert [%{type: :unknown_citation_key, severity: :fatal}] = result.rejected

    assert [%{citation_key: "REC_0001"}] =
             Enum.map(exact_formula.evidence_links, &Map.from_struct/1)

    assert Enum.any?(partial_formula.evidence_links, &(&1.section_id == :open_gaps))
  end

  test "rejects ambiguous exactness and section citation mismatches" do
    package = input_package_fixture()

    result =
      FormulaNormalizer.normalize(package, [
        %{
          formula_text: "score = wins / total + 1",
          exact?: false,
          partial?: false,
          blocked?: false,
          role: :calibration,
          source_section_ids: ["reusable_formulas"],
          supporting_citation_keys: ["REC_0001"]
        },
        %{
          formula_text: "score = wins / total",
          exact?: true,
          partial?: false,
          blocked?: false,
          role: :calibration,
          source_section_ids: ["open_gaps"],
          supporting_citation_keys: ["REC_0001"]
        }
      ])

    assert result.accepted == []

    assert [%{type: :ambiguous_formula_precision}, %{type: :unlinked_formula_provenance}] =
             result.rejected
  end

  test "does not silently upgrade linked-evidence formulas to exact when the synthesis text is still ambiguous" do
    package = input_package_fixture()

    result =
      FormulaNormalizer.normalize(package, [
        %{
          formula_text: "score = wins / total",
          exact?: false,
          partial?: false,
          blocked?: false,
          role: :calibration,
          source_section_ids: ["executive_summary"],
          supporting_citation_keys: ["REC_0001"]
        }
      ])

    assert result.accepted == []
    assert [%{type: :ambiguous_formula_precision}] = result.rejected
  end

  test "requires explicit formula evidence pairs when a citation spans multiple source sections" do
    package = input_package_fixture()

    ambiguous =
      FormulaNormalizer.normalize(package, [
        %{
          formula_text: "score = wins / total",
          exact?: true,
          partial?: false,
          blocked?: false,
          role: :calibration,
          source_section_ids: ["executive_summary", "reusable_formulas"],
          supporting_citation_keys: ["REC_0001"]
        }
      ])

    assert ambiguous.accepted == []
    assert [%{type: :ambiguous_formula_provenance}] = ambiguous.rejected

    resolved =
      FormulaNormalizer.normalize(package, [
        %{
          formula_text: "score = wins / total",
          exact?: true,
          partial?: false,
          blocked?: false,
          role: :calibration,
          source_section_ids: ["executive_summary", "reusable_formulas"],
          supporting_citation_keys: ["REC_0001"],
          evidence_pairs: [
            %{
              section_id: "reusable_formulas",
              citation_key: "REC_0001",
              quote: "score = wins / total"
            }
          ]
        }
      ])

    assert [%{evidence_links: [%{section_id: :reusable_formulas}]}] =
             Enum.map(resolved.accepted, &Map.from_struct/1)
  end

  test "builds strategy specs, suppresses duplicates, classifies readiness, and rejects narrative filler" do
    package = input_package_fixture()

    {:ok, normalized} =
      Strategy.normalize(
        package,
        [
          %{
            formula_text: "score = wins / total",
            exact?: true,
            partial?: false,
            blocked?: false,
            role: :calibration,
            source_section_ids: ["reusable_formulas"],
            supporting_citation_keys: ["REC_0001"]
          }
        ],
        [
          %{
            title: "Calibrate into thin markets",
            thesis: "Trade only when calibration remains above the venue baseline.",
            category: :calibration_strategy,
            candidate_kind: :directly_specified_strategy,
            market_or_domain_applicability: "prediction markets",
            direct_signal_or_rule: "Enter when score exceeds 0.62 and spread is below threshold",
            entry_condition: "score > 0.62",
            exit_condition: "score < 0.55",
            formula_references: [],
            required_features: [
              %{name: "score_feature", status: :available, description: "calibration score"}
            ],
            required_datasets: [
              %{name: "market_quotes", mapping_status: :mapped, description: "quoted markets"}
            ],
            execution_assumptions: [
              %{kind: :execution, description: "cross at midpoint", blocking?: false}
            ],
            sizing_assumptions: [
              %{kind: :sizing, description: "flat unit size", blocking?: false}
            ],
            evidence_references: ["REC_0001"],
            validation_hints: [%{kind: :holdout, description: "test by regime", priority: :high}],
            candidate_metrics: [
              %{name: "hit_rate", description: "win rate", direction: :maximize}
            ],
            falsification_idea: "Edge disappears when calibration is randomized.",
            source_section_ids: ["executive_summary"],
            notes: ["direct evidence"]
          },
          %{
            title: "Calibrate into thin markets",
            thesis: "Trade only when calibration remains above the venue baseline.",
            category: :calibration_strategy,
            candidate_kind: :directly_specified_strategy,
            market_or_domain_applicability: "prediction markets",
            direct_signal_or_rule: "Enter when score exceeds 0.62 and spread is below threshold",
            entry_condition: "score > 0.62",
            exit_condition: "score < 0.55",
            formula_references: [],
            required_features: [
              %{name: "score_feature", status: :available, description: "calibration score"}
            ],
            required_datasets: [
              %{name: "market_quotes", mapping_status: :mapped, description: "quoted markets"}
            ],
            evidence_references: ["REC_0001"],
            source_section_ids: ["executive_summary"],
            notes: ["duplicate wording"]
          },
          %{
            title: "Narrative only",
            thesis: "Researchers find calibration interesting.",
            category: :behavioral_filter_strategy,
            candidate_kind: :speculative_not_backtestable,
            market_or_domain_applicability: "prediction markets",
            evidence_references: ["REC_0001"],
            source_section_ids: ["taxonomy_and_thematic_grouping"]
          }
        ],
        strategy_extraction_run_id: "strategy-run-1"
      )

    assert [spec] = normalized.specs
    assert spec.readiness == :ready_for_backtest
    assert spec.actionability == :immediate

    assert [%{canonical_candidate_id: _id, merged_candidate_ids: [_]}] =
             normalized.validation.duplicate_groups

    assert [%{type: :unsupported_candidate, severity: :warning}] =
             normalized.validation.rejected_candidates
  end

  test "downgrades incomplete and analog candidates instead of surfacing them as ready" do
    package = input_package_fixture()
    formula = hd(FormulaNormalizer.normalize(package, [exact_formula_input()]).accepted)

    result =
      CandidateNormalizer.normalize(package, [formula], [
        Map.merge(strategy_candidate_fixture(formula.id, ["incomplete"]), %{
          title: "Incomplete Formula Strategy"
        }),
        %{
          title: "Analog Transfer",
          thesis: "Transfer the calibration gate from options markets.",
          category: :analog_transfer_strategy,
          candidate_kind: :analog_transfer_candidate,
          market_or_domain_applicability: "prediction markets",
          direct_signal_or_rule: "enter when transferred signal exceeds threshold",
          formula_references: [formula.id],
          required_features: [
            %{name: "formula_feature", status: :available, description: "formula output"}
          ],
          required_datasets: [
            %{name: "venue_quotes", mapping_status: :mapped, description: "quotes"}
          ],
          evidence_references: ["REC_0002"],
          source_section_ids: ["taxonomy_and_thematic_grouping"]
        },
        %{
          title: "Analog Only Direct Strategy",
          thesis: "Reuse the analog liquidity rule as-is.",
          category: :execution_strategy,
          candidate_kind: :directly_specified_strategy,
          market_or_domain_applicability: "prediction markets",
          direct_signal_or_rule: "enter when transferred liquidity signal exceeds threshold",
          formula_references: [formula.id],
          required_features: [
            %{name: "formula_feature", status: :available, description: "formula output"}
          ],
          required_datasets: [
            %{name: "venue_quotes", mapping_status: :mapped, description: "quotes"}
          ],
          evidence_references: ["REC_0002"],
          source_section_ids: ["taxonomy_and_thematic_grouping"]
        }
      ])

    assert [
             %{readiness: :needs_formula_completion},
             %{readiness: :needs_formula_completion},
             %{readiness: :needs_formula_completion, actionability: :exploratory}
           ] =
             result.accepted
  end

  test "requires explicit strategy evidence pairs when citations span multiple source sections" do
    package = input_package_fixture()
    formula = hd(FormulaNormalizer.normalize(package, [exact_formula_input()]).accepted)

    ambiguous =
      CandidateNormalizer.normalize(package, [formula], [
        Map.merge(strategy_candidate_fixture(formula.id, ["ambiguous"]), %{
          source_section_ids: ["executive_summary", "ranked_important_papers_and_findings"]
        })
      ])

    assert ambiguous.accepted == []
    assert [%{type: :ambiguous_strategy_provenance}] = ambiguous.rejected

    resolved =
      CandidateNormalizer.normalize(package, [formula], [
        Map.merge(strategy_candidate_fixture(formula.id, ["resolved"]), %{
          source_section_ids: ["executive_summary", "ranked_important_papers_and_findings"],
          evidence_pairs: [
            %{
              section_id: "executive_summary",
              citation_key: "REC_0001",
              quote: "Use the exact formula when execution frictions are low."
            }
          ]
        })
      ])

    assert [%{evidence_links: [%{section_id: :executive_summary}]}] =
             Enum.map(resolved.accepted, &Map.from_struct/1)
  end

  test "rejects strategy evidence and cautionary citations that are not linked to cited sections" do
    package = input_package_fixture()
    formula = hd(FormulaNormalizer.normalize(package, [exact_formula_input()]).accepted)

    result =
      CandidateNormalizer.normalize(package, [formula], [
        Map.merge(strategy_candidate_fixture(formula.id, ["bad evidence"]), %{
          evidence_references: ["REC_0002"]
        }),
        Map.merge(strategy_candidate_fixture(formula.id, ["bad caution"]), %{
          conflicting_or_cautionary_evidence: ["REC_0002"],
          conflict_note: "REC_0002 is cautionary here"
        })
      ])

    assert result.accepted == []

    assert [%{type: :unlinked_strategy_provenance}, %{type: :unlinked_strategy_provenance}] =
             result.rejected
  end

  property "duplicate suppression keeps one canonical candidate for identical signatures" do
    check all(suffix <- StreamData.string(:alphanumeric, min_length: 1, max_length: 8)) do
      package = input_package_fixture()
      formula = hd(FormulaNormalizer.normalize(package, [exact_formula_input()]).accepted)

      candidate_a = strategy_candidate_fixture(formula.id, ["A #{suffix}"])
      candidate_b = strategy_candidate_fixture(formula.id, ["B #{suffix}"])

      normalized =
        CandidateNormalizer.normalize(package, [formula], [candidate_a, candidate_b]).accepted

      deduped = DuplicateSuppressor.collapse(package, [formula], normalized)

      assert length(deduped.candidates) == 1
    end
  end

  property "blocked formulas never produce ready_for_backtest candidates" do
    check all(title <- StreamData.string(:alphanumeric, min_length: 4, max_length: 12)) do
      package = input_package_fixture()

      blocked_formula =
        hd(
          FormulaNormalizer.normalize(package, [
            %{
              formula_text: "hidden function for #{title}",
              exact?: false,
              partial?: true,
              blocked?: true,
              role: :execution,
              source_section_ids: ["open_gaps"],
              supporting_citation_keys: ["REC_0002"]
            }
          ]).accepted
        )

      [candidate] =
        CandidateNormalizer.normalize(package, [blocked_formula], [
          Map.merge(strategy_candidate_fixture(blocked_formula.id, [title]), %{
            title: "#{title} blocked",
            formula_references: [blocked_formula.id]
          })
        ]).accepted

      refute candidate.readiness == :ready_for_backtest
    end
  end

  property "unknown evidence citations are always rejected" do
    check all(bogus_suffix <- StreamData.integer(9000..9998)) do
      package = input_package_fixture()
      formula = hd(FormulaNormalizer.normalize(package, [exact_formula_input()]).accepted)

      result =
        CandidateNormalizer.normalize(package, [formula], [
          Map.merge(strategy_candidate_fixture(formula.id, ["bogus"]), %{
            evidence_references: ["REC_#{bogus_suffix}"]
          })
        ])

      assert [%{type: :unknown_citation_key, severity: :fatal}] = result.rejected
    end
  end

  defp input_package_fixture do
    bundle = bundle_fixture()
    synthesis_run = synthesis_run_fixture(bundle.snapshot.id)
    artifact = artifact_fixture(bundle.snapshot.id, synthesis_run.id)

    validation = %ValidationResult{
      valid?: true,
      structural_errors: [],
      citation_errors: [],
      formula_errors: [],
      cited_keys: ["REC_0001", "REC_0002"],
      allowed_keys: ["REC_0001", "REC_0002"]
    }

    {:ok, package} = InputBuilder.build(bundle, synthesis_run, artifact, validation)
    package
  end

  defp exact_formula_input do
    %{
      formula_text: "score = wins / total",
      exact?: true,
      partial?: false,
      blocked?: false,
      role: :calibration,
      source_section_ids: ["reusable_formulas"],
      supporting_citation_keys: ["REC_0001"]
    }
  end

  defp strategy_candidate_fixture(formula_id, notes) do
    %{
      title: "Formula backed strategy",
      thesis: "Use the exact formula when execution frictions are low.",
      category: :execution_strategy,
      candidate_kind: :formula_backed_incomplete_strategy,
      market_or_domain_applicability: "prediction markets",
      direct_signal_or_rule: "enter when formula exceeds threshold",
      entry_condition: "formula > 0.7",
      exit_condition: "formula < 0.5",
      formula_references: [formula_id],
      required_features: [
        %{name: "formula_feature", status: :available, description: "formula output"}
      ],
      required_datasets: [%{name: "venue_quotes", mapping_status: :mapped, description: "quotes"}],
      evidence_references: ["REC_0001"],
      source_section_ids: ["executive_summary"],
      notes: notes
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
