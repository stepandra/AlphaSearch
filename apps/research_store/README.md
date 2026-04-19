# ResearchStore

`research_store` owns Postgres persistence for the research pipeline's durable artifacts.

## What This Block Stores

- raw research themes
- normalized themes
- branches, query families, and generated queries
- retrieval runs, search requests, normalized hits, and fetched documents
- raw corpus records, canonical corpus records, duplicate groups, and QA decisions
- immutable `corpus_snapshot` artifacts for downstream synthesis
- synthesis runs, validation results, and finalized report artifacts

## Corpus Snapshot Meaning

A `corpus_snapshot` is the finalized evidence bundle for one QA-approved corpus state.
It records:

- the accepted core, accepted analog, and background canonical records included in the snapshot
- the quarantine records held back from downstream synthesis
- duplicate-group IDs relevant to the finalized corpus
- discard and QA summary metadata
- lineage back to normalized themes, branches, retrieval runs, and raw records

Snapshots are append-only finalized artifacts. The store creates them in a finalized state,
and the database rejects direct updates to snapshot rows.

## Stable Identifiers

The registry uses deterministic artifact IDs for theme, branch, query, decision, and snapshot artifacts.
This allows safe re-insertion and reproducible lookup without inventing a generic artifact engine.

Downstream synthesis should consume:

- `ResearchStore.CorpusRegistry.load_snapshot/1`
- `ResearchStore.CorpusRegistry.accepted_core_records/1`
- `ResearchStore.CorpusRegistry.accepted_analog_records/1`
- `ResearchStore.CorpusRegistry.quarantine_records/1`
- `ResearchStore.CorpusRegistry.provenance_summary/1`
- `ResearchStore.latest_synthesis_run_for_snapshot/2`
- `ResearchStore.successful_synthesis_artifact/2`
- `ResearchStore.list_snapshot_reports/1`

Downstream strategy consumers should consume:

- `ResearchStore.strategy_specs_for_snapshot/2`
- `ResearchStore.ready_strategy_specs_for_snapshot/2`
- `ResearchStore.strategy_specs_for_branch/2`
- `ResearchStore.strategy_specs_for_theme/2`
- `ResearchStore.latest_strategy_specs_for_branch/2`
- `ResearchStore.latest_strategy_specs_for_theme/2`
- `ResearchStore.strategy_formulas_for_spec/1`
- `ResearchStore.strategy_spec_with_provenance/1`

## Non-Goals

This block does not do any of the following:

- prompt/profile design logic
- hypothesis extraction
- knowledge graph reasoning
- branch scoring
- retrieval execution itself
- QA classification logic beyond persisting outputs from `research_core`

See [docs/evidence_store_registry.md](../../docs/evidence_store_registry.md) for the full persistence model and [docs/synthesis_report_builder.md](../../docs/synthesis_report_builder.md) for the synthesis/report layer built on top of it.
