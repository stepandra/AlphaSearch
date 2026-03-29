# Build Evidence Store / Corpus Registry

## Objective
Implement the persistence and registry layer for research artifacts and corpus outputs.

This block must:
- persist the outputs of previous blocks
- version and register corpus snapshots
- preserve lineage from theme and branch generation through retrieval and corpus QA
- expose stable registry/query interfaces for downstream synthesis and hypothesis-building

This block is only about persistence, registry structure, and reproducible artifact lookup.
Do not implement synthesis, hypothesis extraction, knowledge graph reasoning, branch scoring, or backtest logic.

## Context
Previous blocks already provide:
- normalized themes
- branches
- query families
- retrieval runs and normalized hits
- fetched documents
- canonical corpus records
- duplicate groups
- QA decisions
- accepted_core / accepted_analog / background / quarantine / discard outputs

We now need a durable registry layer so these results become reusable, reproducible research artifacts.

This layer must support:
- re-running synthesis on a specific corpus snapshot
- comparing corpus versions across runs
- tracing which queries and retrieval runs produced which accepted evidence
- preserving auditability and provenance
- avoiding recomputation of already validated intermediate artifacts

## Requirements

### Part A — Persistence Model
1. Implement persistence models and migrations for the core research artifacts needed at this stage.

At minimum, support persistence for:
- research themes
- normalized themes
- branches
- query families / generated queries
- retrieval runs
- normalized retrieval hits
- fetched documents
- canonical corpus records
- duplicate groups
- QA decisions
- corpus snapshots or evidence bundles

2. Define a stable concept of a versioned corpus artifact, such as:
- `corpus_snapshot`
or
- `evidence_bundle`

This artifact must be able to represent:
- accepted_core set
- accepted_analog set
- background set
- quarantine set
- discard summary
- QA summary metadata
- source lineage

3. The persistence model must preserve lineage between stages.
At minimum, the registry must be able to answer:
- which theme/run produced this branch?
- which branch produced this query?
- which query produced this retrieval run?
- which retrieval outputs fed this canonical corpus record?
- which QA decision placed this record into accepted_core / analog / quarantine / discard?
- which corpus snapshot contains this record?

### Part B — Repository / Registry API
4. Implement explicit registry modules or repository-facing APIs for:
- storing research themes and normalized themes
- storing branch/query generation outputs
- storing retrieval outputs
- storing canonical corpus outputs
- creating a corpus snapshot / evidence bundle
- loading a corpus snapshot for downstream use
- listing and inspecting prior snapshots

5. Keep registry interfaces explicit and boring.
Do not build a generic repository abstraction layer.

6. Support idempotent or safe insertion patterns where practical, especially for:
- retrieval runs
- fetched documents by exact URL or content fingerprint where appropriate
- canonical corpus records by stable identifiers where appropriate

### Part C — Versioning and Auditability
7. Corpus snapshots must be immutable once finalized, or treated as append-only finalized artifacts.

8. Preserve enough metadata to compare snapshots across runs, including:
- creation time
- upstream theme / branch / run references
- counts by category
- QA summary
- duplicate summary
- quarantine summary

9. Preserve machine-readable auditability for:
- why a record is present in a snapshot
- what upstream run produced it
- what QA decision classified it
- whether it came through duplicate merging

### Part D — Query Surfaces
10. Add explicit read/query surfaces for downstream blocks.
At minimum support loading:
- latest corpus snapshot for a branch or theme
- corpus snapshot by ID
- accepted_core records for a snapshot
- accepted_analog records for a snapshot
- quarantine records and reasons for a snapshot
- duplicate groups for a snapshot
- provenance summary for a canonical record

11. These query surfaces should be optimized for correctness and inspectability first, not premature performance tricks.

### Part E — Documentation and Tests
12. Add tests for:
- schema constraints
- insertion and retrieval of artifact chains
- corpus snapshot creation
- immutability/finalization behavior where implemented
- lineage reconstruction
- loading accepted_core / analog / quarantine subsets
- failure behavior for missing or invalid references

13. Add developer documentation explaining:
- the persistence model
- the meaning of a corpus snapshot / evidence bundle
- which artifacts are immutable
- which identifiers are stable
- how downstream synthesis should consume this block
- what this block explicitly does not do

## Technical Specifications
- Implement this primarily in the persistence/store app.
- Use Ecto and Postgres for storage.
- Reuse core-domain structs and outputs from previous blocks rather than inventing parallel shapes.
- Prefer explicit schemas and explicit repository modules.
- Use Ecto.Multi where transactional grouping is genuinely useful.
- Avoid broad meta-repository patterns.

## Library and Implementation Rules
- Use Ecto and Postgres.
- Use standard migrations and explicit constraints.
- Use ExUnit for tests.
- Mox is not needed unless a real external boundary must be isolated in tests.
- Do not introduce graph databases.
- Do not introduce event-sourcing frameworks.
- Do not introduce CQRS theatre.
- Do not introduce a generic artifact engine.
- Do not hide persistence semantics behind unnecessary behaviours.

## Constraints
- Do not re-run retrieval in this block.
- Do not perform corpus QA in this block beyond persisting its outputs.
- Do not synthesize reports.
- Do not extract hypotheses.
- Do not build knowledge graph reasoning.
- Do not implement branch scoring.
- Do not package backtests.
- Do not silently mutate finalized corpus snapshots.

## Anti-Goals
- No literature synthesis
- No LLM calls
- No KG reasoning
- No graph DB
- No event-sourcing ceremony
- No generic repository abstraction
- No hidden mutation of finalized artifacts
- No persistence-driven rewrites of core domain structs

## Deliverables
1. Ecto schemas and migrations for research artifacts
2. Registry modules / persistence APIs
3. Corpus snapshot / evidence bundle creation flow
4. Lineage-preserving persistence
5. Read/query surfaces for downstream blocks
6. Tests and fixtures
7. Documentation and examples

## Success Criteria
- [ ] Research artifacts from previous blocks can be persisted
- [ ] Corpus snapshots / evidence bundles can be created and loaded deterministically
- [ ] Lineage from theme -> branch -> query -> retrieval -> QA -> snapshot is preserved
- [ ] Accepted_core / analog / background / quarantine subsets can be loaded explicitly
- [ ] Finalized corpus snapshots are stable and not silently mutated
- [ ] Tests cover persistence, lineage, and lookup behavior
- [ ] Docs explain guarantees and non-goals
- [ ] No synthesis, KG, or backtest logic has leaked into this block

## Checkpoints
- [ ] CHECKPOINT_1: Schemas and migrations defined
- [ ] CHECKPOINT_2: Theme/branch/query persistence implemented
- [ ] CHECKPOINT_3: Retrieval artifact persistence implemented
- [ ] CHECKPOINT_4: Corpus QA artifact persistence implemented
- [ ] CHECKPOINT_5: Corpus snapshot / evidence bundle creation implemented
- [ ] CHECKPOINT_6: Downstream query surfaces implemented
- [ ] CHECKPOINT_7: Tests added
- [ ] CHECKPOINT_8: Docs and examples added

## Status
- [ ] CHECKPOINT_1
- [ ] CHECKPOINT_2
- [ ] CHECKPOINT_3
- [ ] CHECKPOINT_4
- [ ] CHECKPOINT_5
- [ ] CHECKPOINT_6
- [ ] CHECKPOINT_7
- [ ] CHECKPOINT_8
- [ ] TASK_COMPLETE

## Execution Rules
- Make incremental file changes.
- Update the Status section in this file as checkpoints are completed.
- Mark TASK_COMPLETE only when all success criteria are satisfied.
- Do not continue iterating after TASK_COMPLETE is checked.
- Do not claim completion only in prose.
- Prefer explicit schemas and explicit registry modules over broad abstractions.

## Progress Log
<!-- Update during execution -->
- [ ] Define schemas and migrations
- [ ] Implement theme/branch/query persistence
- [ ] Implement retrieval artifact persistence
- [ ] Implement corpus QA artifact persistence
- [ ] Implement corpus snapshot creation
- [ ] Implement query surfaces
- [ ] Add tests
- [ ] Add docs

## Notes
- This block answers: "How do we store and version research artifacts and QA-approved corpora reproducibly?"
- This block does not answer: "What does the final literature report say?" or "Which hypothesis should be tested first?"
- If the code starts summarizing evidence, scoring branches, or building graph reasoning, it has crossed the boundary.

## Completion Report
When complete, append a short completion report containing:
1. what was implemented
2. what was deliberately deferred
3. exact files added or changed
4. example corpus snapshot / evidence bundle shape
5. example lineage reconstruction
6. remaining limitations
