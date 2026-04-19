defmodule ResearchStore.StrategyRegistryTest do
  use ResearchStore.DataCase, async: true

  alias ResearchCore.Strategy.{
    EvidenceLink,
    ExecutionAssumption,
    ExtractionRun,
    FeatureRequirement,
    FormulaCandidate,
    MetricHint,
    StrategySpec,
    ValidationHint
  }

  alias ResearchCore.Strategy.ValidationResult, as: StrategyValidationResult
  alias ResearchCore.Synthesis.{Artifact, Run}
  alias ResearchCore.Synthesis.ValidationResult, as: SynthesisValidationResult
  alias ResearchStore.Artifacts.{CorpusSnapshot, NormalizedTheme, ResearchBranch, ResearchTheme}
  alias ResearchStore.{Repo, StrategyRegistry, SynthesisRegistry}

  test "persists strategy runs, validation results, formulas, specs, and query surfaces" do
    %{
      snapshot: snapshot,
      normalized_theme: normalized_theme,
      branch: branch,
      synthesis_run: synthesis_run,
      artifact: artifact
    } =
      insert_context_fixture()

    run = %ExtractionRun{
      id: "strategy-run-1",
      corpus_snapshot_id: snapshot.id,
      synthesis_run_id: synthesis_run.id,
      synthesis_artifact_id: artifact.id,
      synthesis_profile_id: artifact.profile_id,
      normalized_theme_id: normalized_theme.id,
      research_branch_id: branch.id,
      state: :pending,
      input_package: %{digest: "package-1"},
      formula_request_spec: %{phase: :formula_extraction},
      strategy_request_spec: %{phase: :strategy_extraction},
      started_at: ~U[2026-03-30 12:45:00Z]
    }

    assert {:ok, %ExtractionRun{id: "strategy-run-1"}} =
             StrategyRegistry.create_run(run)

    formula = %FormulaCandidate{
      id: "formula-1",
      formula_text: "score = wins / total",
      exact?: true,
      partial?: false,
      blocked?: false,
      role: :calibration,
      source_section_ids: [:reusable_formulas],
      source_section_headings: ["Reusable Formulas"],
      supporting_citation_keys: ["REC_0001"],
      supporting_record_ids: ["core-1"],
      evidence_links: [
        %EvidenceLink{
          section_id: :reusable_formulas,
          section_heading: "Reusable Formulas",
          citation_key: "REC_0001",
          record_id: "core-1",
          relation: :supports_formula,
          quote: "score = wins / total",
          provenance_reference: %{providers: ["serper"]}
        }
      ],
      notes: ["exact formula"]
    }

    spec = %StrategySpec{
      id: "strategy-spec-1",
      strategy_candidate_id: "candidate-1",
      strategy_extraction_run_id: run.id,
      corpus_snapshot_id: snapshot.id,
      synthesis_run_id: synthesis_run.id,
      synthesis_artifact_id: artifact.id,
      title: "Calibration Gate",
      thesis: "Trade only when calibration is above the observed threshold.",
      category: :calibration_strategy,
      candidate_kind: :directly_specified_strategy,
      market_or_domain_applicability: "prediction markets",
      decision_rule: %{
        signal_or_rule: "enter when score > 0.62",
        entry_condition: "score > 0.62",
        exit_condition: "score < 0.55",
        formula_ids: [formula.id],
        rule_ids: ["rule-1"]
      },
      formula_ids: [formula.id],
      required_features: [
        %FeatureRequirement{name: "score", description: "formula output", status: :available}
      ],
      required_datasets: [],
      execution_assumptions: [
        %ExecutionAssumption{kind: :execution, description: "cross at midpoint"}
      ],
      sizing_assumptions: [%ExecutionAssumption{kind: :sizing, description: "flat size"}],
      evidence_links: formula.evidence_links,
      conflicting_evidence_links: [],
      expected_edge_source: "miscalibration",
      validation_hints: [
        %ValidationHint{kind: :holdout, description: "holdout by regime", priority: :high}
      ],
      metric_hints: [%MetricHint{name: "hit_rate", description: "win rate", direction: :maximize}],
      falsification_idea: "Randomized calibration breaks the edge.",
      readiness: :ready_for_backtest,
      evidence_strength: :strong,
      actionability: :immediate,
      notes: ["ready"],
      blocked_by: []
    }

    validation = %StrategyValidationResult{
      valid?: true,
      fatal_errors: [],
      warnings: [],
      rejected_formulas: [],
      rejected_candidates: [],
      duplicate_groups: [],
      accepted_formula_ids: [formula.id],
      accepted_strategy_ids: [spec.id],
      validated_at: ~U[2026-03-30 12:46:00Z]
    }

    assert {:ok, %StrategyValidationResult{valid?: true}} =
             StrategyRegistry.put_validation_result(run.id, validation)

    assert {:ok, [%FormulaCandidate{id: "formula-1"}]} =
             StrategyRegistry.replace_formulas(run.id, [formula])

    assert {:ok, [%StrategySpec{id: "strategy-spec-1"}]} =
             StrategyRegistry.replace_strategy_specs(run.id, [spec])

    assert {:ok, %ExtractionRun{state: :completed}} =
             StrategyRegistry.update_run(run.id, %{
               state: :completed,
               completed_at: ~U[2026-03-30 12:47:00Z]
             })

    assert %ExtractionRun{
             id: "strategy-run-1",
             formulas: [%FormulaCandidate{id: "formula-1"}],
             strategy_specs: [%StrategySpec{id: "strategy-spec-1"}]
           } =
             StrategyRegistry.get_run(run.id)

    assert [%StrategySpec{id: "strategy-spec-1"}] =
             ResearchStore.strategy_specs_for_snapshot(snapshot.id)

    assert [%StrategySpec{id: "strategy-spec-1"}] =
             ResearchStore.strategy_specs_for_snapshot(snapshot.id,
               category: :calibration_strategy,
               readiness: :ready_for_backtest
             )

    assert [%StrategySpec{id: "strategy-spec-1"}] =
             ResearchStore.ready_strategy_specs_for_snapshot(snapshot.id)

    assert [%StrategySpec{id: "strategy-spec-1"}] =
             ResearchStore.strategy_specs_for_artifact(artifact.id)

    assert [%StrategySpec{id: "strategy-spec-1"}] =
             ResearchStore.strategy_specs_for_branch(branch.id)

    assert [%StrategySpec{id: "strategy-spec-1"}] =
             ResearchStore.strategy_specs_for_theme(normalized_theme.id)

    assert [%FormulaCandidate{id: "formula-1"}] =
             ResearchStore.strategy_formulas_for_spec(spec.id)

    assert %{
             spec: %StrategySpec{id: "strategy-spec-1"},
             formulas: [%FormulaCandidate{id: "formula-1"}]
           } =
             ResearchStore.strategy_spec_with_provenance(spec.id)

    later_run = %ExtractionRun{
      id: "strategy-run-2",
      corpus_snapshot_id: snapshot.id,
      synthesis_run_id: synthesis_run.id,
      synthesis_artifact_id: artifact.id,
      synthesis_profile_id: artifact.profile_id,
      normalized_theme_id: normalized_theme.id,
      research_branch_id: branch.id,
      state: :completed,
      input_package: %{digest: "package-2"},
      formula_request_spec: %{phase: :formula_extraction},
      strategy_request_spec: %{phase: :strategy_extraction},
      started_at: ~U[2026-03-30 13:00:00Z],
      completed_at: ~U[2026-03-30 13:05:00Z]
    }

    assert {:ok, %ExtractionRun{id: "strategy-run-2"}} =
             StrategyRegistry.create_run(later_run)

    later_formula = %FormulaCandidate{formula | id: "formula-2"}

    later_spec = %StrategySpec{
      spec
      | id: "strategy-spec-2",
        title: "Calibration Gate v2",
        strategy_extraction_run_id: later_run.id,
        formula_ids: [later_formula.id]
    }

    assert {:ok, [%FormulaCandidate{id: "formula-2"}]} =
             StrategyRegistry.replace_formulas(later_run.id, [later_formula])

    assert {:ok, [%StrategySpec{id: "strategy-spec-2"}]} =
             StrategyRegistry.replace_strategy_specs(later_run.id, [later_spec])

    assert [%StrategySpec{id: "strategy-spec-2"}] =
             ResearchStore.latest_strategy_specs_for_branch(branch.id)

    assert [%StrategySpec{id: "strategy-spec-2"}] =
             ResearchStore.latest_strategy_specs_for_theme(normalized_theme.id)
  end

  defp insert_context_fixture do
    theme =
      %ResearchTheme{}
      |> ResearchTheme.changeset(%{
        id: "theme-1",
        raw_text: "prediction market calibration",
        source: "manual",
        content_hash: "hash-theme-1"
      })
      |> Repo.insert!()

    normalized_theme =
      %NormalizedTheme{}
      |> NormalizedTheme.changeset(%{
        id: "normalized-theme-1",
        research_theme_id: theme.id,
        original_input: theme.raw_text,
        normalized_text: "prediction market calibration",
        topic: "prediction market calibration"
      })
      |> Repo.insert!()

    branch =
      %ResearchBranch{}
      |> ResearchBranch.changeset(%{
        id: "branch-1",
        normalized_theme_id: normalized_theme.id,
        kind: "direct",
        label: "prediction market calibration",
        rationale: "focus on direct evidence",
        theme_relation: "direct"
      })
      |> Repo.insert!()

    snapshot =
      %CorpusSnapshot{}
      |> CorpusSnapshot.changeset(%{
        id: "snapshot-1",
        label: "prediction-market-calibration",
        finalized_at: ~U[2026-03-30 12:00:00Z],
        normalized_theme_ids: [normalized_theme.id],
        branch_ids: [branch.id],
        retrieval_run_ids: ["run-1"],
        qa_summary: %{"accepted_core" => 1}
      })
      |> Repo.insert!()

    synthesis_run = %Run{
      id: "synthesis-run-1",
      corpus_snapshot_id: snapshot.id,
      normalized_theme_id: normalized_theme.id,
      research_branch_id: branch.id,
      profile_id: "literature_review_v1",
      state: :completed,
      input_package: %{digest: "input-1"},
      request_spec: %{prompt: "prompt"},
      started_at: ~U[2026-03-30 12:05:00Z],
      completed_at: ~U[2026-03-30 12:10:00Z]
    }

    assert {:ok, %Run{} = persisted_run} = SynthesisRegistry.create_run(synthesis_run)

    assert {:ok, %SynthesisValidationResult{valid?: true}} =
             SynthesisRegistry.put_validation_result(
               persisted_run.id,
               %SynthesisValidationResult{
                 valid?: true,
                 structural_errors: [],
                 citation_errors: [],
                 formula_errors: [],
                 cited_keys: ["REC_0001"],
                 allowed_keys: ["REC_0001"],
                 unknown_keys: [],
                 validated_at: ~U[2026-03-30 12:11:00Z],
                 metadata: %{}
               }
             )

    artifact = %Artifact{
      id: "synthesis-artifact-1",
      synthesis_run_id: persisted_run.id,
      corpus_snapshot_id: snapshot.id,
      profile_id: persisted_run.profile_id,
      format: :markdown,
      content: "## Executive Summary\nValid [REC_0001]",
      artifact_hash: "artifact-hash-1",
      finalized_at: ~U[2026-03-30 12:12:00Z],
      section_headings: ["Executive Summary"],
      cited_keys: ["REC_0001"],
      summary: %{}
    }

    assert {:ok, %Artifact{} = persisted_artifact} = SynthesisRegistry.put_artifact(artifact)

    %{
      snapshot: snapshot,
      normalized_theme: normalized_theme,
      branch: branch,
      synthesis_run: persisted_run,
      artifact: persisted_artifact
    }
  end
end
