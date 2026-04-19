# Evidence Store Registry

## Persistence Model

The evidence store lives in `research_store` and persists the artifact chain end-to-end:

- `research_themes`
- `normalized_themes`
- `research_branches`
- `query_families`
- `generated_queries`
- `retrieval_runs`
- `retrieval_search_requests`
- `normalized_retrieval_hits`
- `fetched_documents`
- `raw_corpus_records`
- `canonical_corpus_records`
- `duplicate_groups`
- `qa_decisions`
- `quarantine_records`
- `corpus_snapshots`
- `synthesis_runs`
- `synthesis_validation_results`
- `synthesis_artifacts`

The store keeps explicit foreign keys and deterministic IDs instead of a generic artifact abstraction.

## Corpus Snapshot / Evidence Bundle

A `corpus_snapshot` is the stable evidence bundle consumed by downstream synthesis.
It contains:

- accepted core records
- accepted analog records
- background records
- quarantine records and reasons
- duplicate-group references
- discard summary metadata
- QA summary metadata
- source lineage back to themes, branches, runs, and raw records

Snapshots are created finalized and treated as append-only artifacts.

## Stable IDs And Immutability

Stable IDs are deterministic for theme, normalized-theme, branch, query-family, generated-query,
QA-decision, and corpus-snapshot records. This allows idempotent insertion and reproducible lookup.

`corpus_snapshots` are immutable once created. The database rejects direct updates or deletes of snapshot rows.

## Downstream Consumption

Downstream synthesis should read from the explicit query surfaces:

- `ResearchStore.CorpusRegistry.load_snapshot/1`
- `ResearchStore.CorpusRegistry.latest_snapshot_for_theme/1`
- `ResearchStore.CorpusRegistry.latest_snapshot_for_branch/1`
- `ResearchStore.CorpusRegistry.accepted_core_records/1`
- `ResearchStore.CorpusRegistry.accepted_analog_records/1`
- `ResearchStore.CorpusRegistry.quarantine_records/1`
- `ResearchStore.CorpusRegistry.duplicate_groups/1`
- `ResearchStore.CorpusRegistry.provenance_summary/1`
- `ResearchStore.latest_synthesis_run_for_snapshot/2`
- `ResearchStore.successful_synthesis_artifact/2`
- `ResearchStore.list_snapshot_reports/1`

Downstream callers should treat the snapshot as the reproducible corpus boundary and avoid re-running retrieval or QA when the snapshot already exists.

## Explicit Non-Goals

This block does not implement:

- synthesis
- hypothesis extraction
- knowledge graph reasoning
- branch scoring
- backtests
- retrieval execution
- new QA heuristics

## Example Snapshot Shape

```elixir
%{
  snapshot: %ResearchStore.Artifacts.CorpusSnapshot{
    id: "corpus_snapshot_...",
    finalized_at: ~U[2026-03-30 00:00:00Z],
    normalized_theme_ids: ["normalized_theme_..."],
    branch_ids: ["branch_..."],
    retrieval_run_ids: ["run-001"]
  },
  accepted_core: [%ResearchCore.Corpus.CanonicalRecord{}],
  accepted_analog: [%ResearchCore.Corpus.CanonicalRecord{}],
  background: [%ResearchCore.Corpus.CanonicalRecord{}],
  quarantine: [%ResearchCore.Corpus.QuarantineRecord{}],
  duplicate_groups: [%ResearchCore.Corpus.DuplicateGroup{}]
}
```

## Example Lineage Reconstruction

A canonical record's provenance can be reconstructed with `ResearchStore.CorpusRegistry.provenance_summary/1`,
which returns the canonical record together with:

- raw-record summaries
- normalized retrieval hits
- retrieval runs
- QA decisions
- snapshots that include the record
