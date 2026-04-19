# Synthesis Report Builder

## What A Synthesis Run Is

A synthesis run is the durable execution record for turning one finalized `corpus_snapshot`
into one explicit report profile such as `literature_review_v1`.

Each run captures:

- the source snapshot ID
- any derivable normalized-theme or branch context
- the explicit profile ID and version
- the deterministic synthesis input package
- the inspectable request spec/prompt payload
- provider/model metadata and request/response hashes
- the machine-readable validation result
- the finalized report artifact when validation succeeds

## Snapshot To Report Flow

1. Load a finalized snapshot through `ResearchStore.CorpusRegistry.load_snapshot/1`.
2. Build a deterministic `ResearchCore.Synthesis.InputPackage` from the accepted snapshot records.
3. Assign stable citation keys like `REC_0001` in deterministic order.
4. Build the explicit report request with `ResearchCore.Synthesis.PromptBuilder`.
5. Execute the request through the narrow provider boundary in `research_jobs`.
6. Validate structure, citations, and formula integrity before accepting output.
7. Persist the run, validation result, and finalized artifact through `ResearchStore.SynthesisRegistry`.

## Citation Keys

Citation keys are stable report-facing handles for records included in the synthesis input package.
The first profile uses keys shaped like `REC_0001`.

Guarantees:

- keys are assigned deterministically from the included snapshot record order
- reports must cite only these keys
- unknown keys fail validation
- unused keys are allowed
- free-form bibliography references are not the primary linkage mechanism

## Validator Guarantees

`ResearchCore.Synthesis.Validator` enforces these guarantees before a report artifact is accepted:

- required sections exist
- required sections appear in the configured order
- disallowed or unknown sections are rejected
- output is markdown with explicit top-level sections
- citations resolve only to records present in the synthesis input package
- formula-like text is rejected for records that do not carry exact reusable formulas

The validator does not determine truth. It guarantees that accepted reports stay structurally tied to the finalized snapshot boundary.

## Explicit Non-Goals

This block does not do any of the following:

- rerun retrieval
- change corpus QA decisions
- mutate snapshot contents
- extract hypotheses
- build a knowledge graph
- score branches
- package backtests
- silently edit finalized reports

## Downstream Consumption

Downstream hypothesis-building should treat synthesized reports as audited read models.
Later blocks should consume them through explicit query surfaces such as:

- `ResearchStore.latest_synthesis_run_for_snapshot/2`
- `ResearchStore.successful_synthesis_artifact/2`
- `ResearchStore.list_snapshot_reports/1`
- `ResearchStore.latest_branch_report/2`
- `ResearchStore.latest_theme_report/2`

Those later blocks may interpret or extend the synthesis artifact, but they should not rewrite the original artifact or bypass the citation discipline that ties the report back to the snapshot.

## Example Shapes

```elixir
%ResearchCore.Synthesis.InputPackage{
  snapshot_id: "corpus_snapshot_123",
  profile_id: "literature_review_v1",
  citation_keys: [%ResearchCore.Synthesis.CitationKey{key: "REC_0001", record_id: "canon-1"}],
  accepted_core: [
    %{
      record_id: "canon-1",
      citation_key: "REC_0001",
      title: "Calibration Under Stress",
      formula: %{status: :exact, exact_reusable_formula_texts: ["score = wins / total"]}
    }
  ]
}

%ResearchCore.Synthesis.Artifact{
  id: "synthesis_artifact_123",
  profile_id: "literature_review_v1",
  format: :markdown,
  cited_keys: ["REC_0001"],
  section_headings: ["Executive Summary", "Evidence Appendix"]
}

%ResearchCore.Synthesis.ValidationResult{
  valid?: false,
  citation_errors: [%{type: :unknown_citation_key, message: "report cited REC_9999"}],
  structural_errors: [%{type: :missing_required_section, message: "required section `Open Gaps` is missing"}]
}
```
