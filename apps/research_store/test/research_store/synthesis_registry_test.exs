defmodule ResearchStore.SynthesisRegistryTest do
  use ResearchStore.DataCase, async: true

  alias ResearchCore.Corpus.{CanonicalRecord, SourceIdentifiers, SourceProvenanceSummary}
  alias ResearchCore.Synthesis.{Artifact, InputBuilder, Run, ValidationResult}
  alias ResearchStore.Artifacts.{CorpusSnapshot, NormalizedTheme, ResearchBranch, ResearchTheme}
  alias ResearchStore.SynthesisRegistry

  test "persists synthesis runs, artifacts, validation results, and query surfaces" do
    %{snapshot: snapshot, normalized_theme: normalized_theme, branch: branch} =
      insert_context_fixture()

    profile = ResearchCore.Synthesis.profile!("literature_review_v1")
    {:ok, package} = InputBuilder.build(profile, bundle(snapshot))

    completed_run = %Run{
      id: "synthesis-run-completed",
      corpus_snapshot_id: snapshot.id,
      normalized_theme_id: normalized_theme.id,
      research_branch_id: branch.id,
      profile_id: profile.id,
      state: :pending,
      input_package: package,
      request_spec: %{prompt: "prompt"},
      started_at: ~U[2026-03-30 10:10:00Z]
    }

    assert {:ok, %Run{id: "synthesis-run-completed"}} =
             SynthesisRegistry.create_run(completed_run)

    valid_result = %ValidationResult{
      valid?: true,
      structural_errors: [],
      citation_errors: [],
      formula_errors: [],
      cited_keys: ["REC_0001"],
      allowed_keys: ["REC_0001"],
      unknown_keys: [],
      validated_at: ~U[2026-03-30 10:11:00Z],
      metadata: %{headings: ["Executive Summary"]}
    }

    assert {:ok, %ValidationResult{valid?: true}} =
             SynthesisRegistry.put_validation_result(completed_run.id, valid_result)

    artifact = %Artifact{
      id: "artifact-1",
      synthesis_run_id: completed_run.id,
      corpus_snapshot_id: snapshot.id,
      profile_id: profile.id,
      format: :markdown,
      content: "## Executive Summary\nValid [REC_0001]",
      artifact_hash: "hash-1",
      finalized_at: ~U[2026-03-30 10:12:00Z],
      section_headings: ["Executive Summary"],
      cited_keys: ["REC_0001"],
      summary: %{package_digest: package.digest}
    }

    assert {:ok, %Artifact{id: "artifact-1"}} = SynthesisRegistry.put_artifact(artifact)

    assert {:ok, %Run{state: :completed}} =
             SynthesisRegistry.update_run(completed_run.id, %{state: :completed})

    failed_run = %Run{
      id: "synthesis-run-failed",
      corpus_snapshot_id: snapshot.id,
      normalized_theme_id: normalized_theme.id,
      research_branch_id: branch.id,
      profile_id: profile.id,
      state: :pending,
      input_package: package,
      request_spec: %{prompt: "prompt"},
      started_at: ~U[2026-03-30 10:20:00Z]
    }

    assert {:ok, %Run{id: "synthesis-run-failed"}} = SynthesisRegistry.create_run(failed_run)

    failed_validation = %ValidationResult{
      valid?: false,
      structural_errors: [%{type: :missing_required_section, message: "missing"}],
      citation_errors: [%{type: :unknown_citation_key, message: "unknown"}],
      formula_errors: [],
      cited_keys: ["REC_9999"],
      allowed_keys: ["REC_0001"],
      unknown_keys: ["REC_9999"],
      validated_at: ~U[2026-03-30 10:21:00Z],
      metadata: %{}
    }

    assert {:ok, %ValidationResult{valid?: false}} =
             SynthesisRegistry.put_validation_result(failed_run.id, failed_validation)

    assert {:ok, %Run{state: :validation_failed}} =
             SynthesisRegistry.update_run(failed_run.id, %{state: :validation_failed})

    assert %Run{id: "synthesis-run-failed", validation_result: %ValidationResult{valid?: false}} =
             SynthesisRegistry.latest_run_for_snapshot(snapshot.id, profile.id)

    assert %Run{id: "synthesis-run-completed", artifact: %Artifact{id: "artifact-1"}} =
             SynthesisRegistry.get_run(completed_run.id)

    assert %Artifact{id: "artifact-1"} =
             SynthesisRegistry.successful_artifact_for_snapshot(snapshot.id, profile.id)

    assert %ValidationResult{valid?: false, unknown_keys: ["REC_9999"]} =
             SynthesisRegistry.validation_failures(failed_run.id)

    assert [%Artifact{id: "artifact-1"}] =
             SynthesisRegistry.list_reports_for_snapshot(snapshot.id)

    assert %Artifact{id: "artifact-1"} =
             SynthesisRegistry.latest_report_for_branch(branch.id, profile.id)

    assert %Artifact{id: "artifact-1"} =
             SynthesisRegistry.latest_report_for_theme(normalized_theme.id, profile.id)
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
        finalized_at: ~U[2026-03-30 10:00:00Z],
        normalized_theme_ids: [normalized_theme.id],
        branch_ids: [branch.id],
        retrieval_run_ids: ["run-1"],
        qa_summary: %{"accepted_core" => 1}
      })
      |> Repo.insert!()

    %{snapshot: snapshot, normalized_theme: normalized_theme, branch: branch}
  end

  defp bundle(snapshot) do
    %{
      snapshot: snapshot,
      accepted_core: [record("canon-core", "Calibration Under Stress", :accepted_core, :exact)],
      accepted_analog: [],
      background: [],
      quarantine: []
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
