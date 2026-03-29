# Build Corpus QA / Canonicalization / Filtering

## Objective
Implement the corpus-quality layer for the research platform.

This block must:
- accept raw retrieved source material
- canonicalize records
- detect and split malformed or conflated records
- filter low-quality or invalid records
- classify records into usable buckets
- preserve auditability for every acceptance, rejection, quarantine, and merge decision

This block is only about corpus quality control and corpus shaping.
Do not implement literature synthesis, hypothesis extraction, knowledge graph logic, branch scoring, or backtest logic.

## Context
Previous blocks already provide:
- normalized themes
- branches
- query families
- retrieval runs
- normalized search hits
- fetched page content
- provider provenance

The research system now needs a strict corpus gate between:
raw retrieval output
and
evidence synthesis.

This block must prevent bad corpora from poisoning later steps.

The quality problems we explicitly expect include:
- URL-only pseudo-citations
- placeholder or generic titles
- duplicate records across providers
- near-duplicate records across source variants
- conflated multi-paper records
- missing methodology / missing venue / missing limitations
- thin or irrelevant records
- weak analogs mixed with core evidence
- papers where formulas are referenced but not extracted cleanly

This layer must make these problems explicit and machine-usable.

## Requirements

### Part A — Canonical Record Model
1. Define explicit data structures for:
   - raw corpus record
   - canonical corpus record
   - duplicate group
   - quarantine record
   - acceptance decision
   - rejection reason
   - record classification
   - formula completeness status
   - source provenance summary

2. Canonical corpus records must support fields such as:
   - canonical title
   - canonical citation
   - year
   - authors if available
   - source type
   - source identifiers where available (DOI / arXiv / SSRN / NBER / OSF / URL)
   - abstract or content excerpt if available
   - methodology summary if available
   - findings summary if available
   - limitations summary if available
   - direct product implication if available
   - market type or analog type if available
   - relevance score fields
   - evidence score fields
   - formula completeness status
   - provenance trace

3. The canonical model must distinguish:
   - original raw retrieved data
   - normalized extracted fields
   - QA decisions made by this block

### Part B — Canonicalization
4. Implement canonicalization logic for:
   - titles
   - citations
   - URLs
   - identifiers
   - author strings where practical
   - year fields
   - source labels

5. Implement exact and near-duplicate detection using explicit, inspectable rules.
At minimum support:
   - exact identifier match
   - exact normalized title match
   - exact canonical URL match
   - strong near-duplicate title match where practical

6. Create duplicate groups and select or derive a canonical representative record.

7. Preserve merge provenance:
   - which raw records were grouped
   - why they were grouped
   - what canonical record was selected or built

### Part C — Conflated and Malformed Records
8. Detect likely conflated records where a single retrieved record appears to contain multiple papers or mixed citations.

9. For conflated records:
   - either split them into multiple candidate records if this can be done safely and explicitly
   - or quarantine them with a clear reason if safe splitting is not possible

10. Detect malformed records such as:
   - URL-only pseudo-citation
   - year = 0 or missing year
   - placeholder title
   - clearly incomplete metadata
   - missing critical evidence fields beyond allowed thresholds

### Part D — Filtering and Classification
11. Classify each canonical or quarantined record into one of:
   - accepted_core
   - accepted_analog
   - background
   - quarantine
   - discard

12. Implement explicit rule-based scoring or classification fields for at least:
   - relevance to the research branch or theme
   - evidence strength
   - transferability
   - citation quality / canonicality
   - formula actionability
   - external-validity risk or venue-specificity flag

13. Implement hard-fail rules for quarantine or discard.
Examples:
   - URL-only citation with no other usable metadata
   - year missing or zero
   - empty methodology + empty findings + empty limitations beyond threshold
   - placeholder or obviously generic title
   - unsafe conflation that cannot be split reliably

14. Implement softer classification rules for:
   - analog but useful
   - background only
   - weak theory without empirical value
   - venue-specific evidence with limited transferability

15. Preserve a machine-readable audit trail for every decision:
   - accepted
   - downgraded
   - quarantined
   - discarded
   - merged

### Part E — Formula Completeness
16. Add explicit formula completeness status such as:
   - exact
   - partial
   - referenced_only
   - none
   - unknown

17. Do not extract formulas deeply in this block.
Only classify whether formula usability appears sufficient for downstream synthesis.

### Part F — Outputs
18. Produce outputs that downstream synthesis can consume cleanly:
   - accepted_core set
   - accepted_analog set
   - background set
   - quarantine set
   - discard log
   - duplicate-group log
   - QA decision summary

19. Make these outputs deterministic and inspectable.

### Part G — Documentation and Tests
20. Add tests for:
   - canonicalization
   - exact duplicate grouping
   - near-duplicate grouping where implemented
   - malformed record detection
   - conflated record handling
   - hard-fail quarantine rules
   - accepted_core / analog / background classification
   - audit trail generation

21. Add developer documentation explaining:
   - the QA pipeline stages
   - what qualifies as core / analog / background
   - what goes to quarantine
   - what this block guarantees
   - what this block explicitly does not do

## Technical Specifications
- Implement inside the existing umbrella project.
- Keep pure corpus QA logic explicit and testable.
- Place persistence or workflow glue only where truly needed.
- Prefer deterministic rule-based logic over fuzzy black-box judgments.
- Reuse retrieval output contracts from the previous block rather than inventing parallel shapes.

## Library and Testing Rules
- Prefer standard library and pure functions where possible.
- TypedStruct is acceptable for core structs.
- NimbleOptions is acceptable for config validation.
- ExUnit and StreamData should be used for testing where helpful.
- Mox is allowed only if a real external boundary from previous blocks must be isolated in tests.
- Do not introduce embeddings.
- Do not introduce vector search.
- Do not introduce LLM-based evidence grading.
- Do not introduce a rule engine DSL unless there is a very strong reason.

## Constraints
- Do not call external search APIs in this block.
- Do not re-run retrieval here.
- Do not synthesize final reports.
- Do not extract hypotheses.
- Do not build the knowledge graph.
- Do not rank research branches globally.
- Do not run backtests.
- Do not hide decisions behind opaque scoring.
- Do not silently drop bad records without a reason.

## Anti-Goals
- No literature report generation
- No semantic summarizer pipeline
- No embeddings or clustering engine
- No graph persistence
- No backtest packaging
- No black-box evidence scoring
- No silent dedupe with no provenance
- No silent discard with no audit reason

## Deliverables
1. Canonical corpus record model
2. Duplicate-group and quarantine model
3. Canonicalization pipeline
4. Conflated-record handling
5. Hard-fail and soft classification rules
6. Deterministic outputs for accepted_core / analog / background / quarantine / discard
7. Tests and fixtures
8. Documentation and examples

## Success Criteria
- [x] Canonical corpus records can be produced from raw retrieval outputs
- [x] Exact and near-duplicate records can be grouped explicitly
- [x] Malformed or conflated records are handled explicitly
- [x] Hard-fail quarantine rules are implemented
- [x] Records can be classified into core / analog / background / quarantine / discard
- [x] Formula completeness status is recorded
- [x] Every QA decision preserves auditability
- [x] Tests cover normal and bad-input cases
- [x] Docs explain guarantees and non-goals
- [x] No synthesis, hypothesis, KG, or backtest logic has leaked into this block

## Checkpoints
- [x] CHECKPOINT_1: Canonical corpus structs defined
- [x] CHECKPOINT_2: Canonicalization implemented
- [x] CHECKPOINT_3: Duplicate grouping implemented
- [x] CHECKPOINT_4: Conflated/malformed detection implemented
- [x] CHECKPOINT_5: Classification rules implemented
- [x] CHECKPOINT_6: Formula completeness status added
- [x] CHECKPOINT_7: Audit trail outputs implemented
- [x] CHECKPOINT_8: Tests added
- [x] CHECKPOINT_9: Docs and examples added

## Status
- [x] CHECKPOINT_1
- [x] CHECKPOINT_2
- [x] CHECKPOINT_3
- [x] CHECKPOINT_4
- [x] CHECKPOINT_5
- [x] CHECKPOINT_6
- [x] CHECKPOINT_7
- [x] CHECKPOINT_8
- [x] CHECKPOINT_9
- [x] TASK_COMPLETE

## Execution Rules
- Make incremental file changes.
- Update the Status section in this file as checkpoints are completed.
- Mark TASK_COMPLETE only when all success criteria are satisfied.
- Do not continue iterating after TASK_COMPLETE is checked.
- Do not claim completion only in prose.
- Prefer explicit rule-based logic over fuzzy general frameworks.

## Progress Log
<!-- Update during execution -->
- [x] Define canonical record structs
- [x] Implement canonicalization
- [x] Implement duplicate grouping
- [x] Implement malformed/conflated detection
- [x] Implement classification rules
- [x] Add formula completeness status
- [x] Add audit trail outputs
- [x] Add tests
- [x] Add docs

## Notes
- This block answers: "Which retrieved records are structurally usable for downstream evidence synthesis?"
- This block does not answer: "What is the final literature narrative?" or "Which hypothesis should we trade?"
- If the code starts summarizing evidence, generating research conclusions, or building graph memory, it has crossed the boundary.

## Completion Report
When complete, append a short completion report containing:
1. what was implemented
2. what was deliberately deferred
3. exact files added or changed
4. example accepted_core / analog / quarantine outputs
5. example duplicate-group decisions
6. remaining limitations

### Completion Report

1. What was implemented
- Added the `ResearchCore.Corpus` QA surface with explicit structs for raw records, canonical records, duplicate groups, quarantine records, decisions, classifications, rejection reasons, formula completeness, provenance summaries, and final QA outputs.
- Implemented the deterministic QA pipeline in `ResearchCore.Corpus.QA` covering conflation preprocessing, canonicalization, duplicate grouping, hard-fail handling, rule-based classification, formula usability status, and machine-readable audit logs.
- Added focused tests for canonicalization, duplicate grouping, malformed inputs, conflation splitting/quarantine, classification buckets, audit trails, and documentation coverage.
- Added corpus-quality developer documentation describing stages, buckets, guarantees, non-goals, and example outputs.

2. What was deliberately deferred
- No literature synthesis, hypothesis extraction, knowledge graph logic, backtests, embeddings, or retrieval retries were added.
- Formula handling remains a coarse usability classification only; this block does not deeply parse or normalize equations.
- No persistence or orchestration layer was added around QA outputs.

3. Exact files added or changed
- Changed `PROMPT.md`
- Added `apps/research_core/lib/research_core/corpus.ex`
- Added `apps/research_core/lib/research_core/corpus/acceptance_decision.ex`
- Added `apps/research_core/lib/research_core/corpus/canonical_record.ex`
- Added `apps/research_core/lib/research_core/corpus/duplicate_group.ex`
- Added `apps/research_core/lib/research_core/corpus/formula_completeness_status.ex`
- Added `apps/research_core/lib/research_core/corpus/qa.ex`
- Added `apps/research_core/lib/research_core/corpus/qa_result.ex`
- Added `apps/research_core/lib/research_core/corpus/quarantine_record.ex`
- Added `apps/research_core/lib/research_core/corpus/raw_record.ex`
- Added `apps/research_core/lib/research_core/corpus/record_classification.ex`
- Added `apps/research_core/lib/research_core/corpus/rejection_reason.ex`
- Added `apps/research_core/lib/research_core/corpus/source_identifiers.ex`
- Added `apps/research_core/lib/research_core/corpus/source_provenance_summary.ex`
- Added `apps/research_core/test/research_core/corpus/qa_test.exs`
- Added `apps/research_core/test/research_core/corpus/structs_test.exs`
- Added `apps/research_core/test/corpus_quality_documentation_test.exs`
- Added `docs/corpus_quality.md`

4. Example accepted_core / analog / quarantine outputs
- `accepted_core`: `%CanonicalRecord{id: "canonical-record:f6af46a087e6", classification: :accepted_core, canonical_title: "Prediction Market Calibration Under Stress", formula_completeness_status: :exact}`
- `accepted_analog`: `%CanonicalRecord{classification: :accepted_analog, canonical_title: "Options Market Calibration for Thin Liquidity", market_type: "options market"}`
- `quarantine`: `%QuarantineRecord{id: "quarantine:canonical-record:...", reason_codes: [:missing_year]}` and `%QuarantineRecord{id: "quarantine:raw-unsafe", reason_codes: [:unsafe_conflation]}`

5. Example duplicate-group decisions
- Exact duplicate merge: two records sharing DOI `10.5555/cal-1` are grouped into one `DuplicateGroup` with `match_reasons: [%{rule: :exact_identifier, identifier: :doi, value: "10.5555/cal-1"}]` and a `:merged` audit decision for the losing canonical member.
- Near-duplicate merge: reordered titles like `Prediction Market Calibration with Order Book Signals` and `Order Book Signals for Prediction Market Calibration` are grouped with `rule: :near_duplicate_title` plus shared token and year-compatibility evidence.

6. Remaining limitations
- Near-duplicate detection is intentionally rule-based and conservative; it does not attempt semantic clustering.
- Split records keep shared provenance and URL lineage, so downstream systems should still treat them as candidates derived from one fetched source.
- Repo-level `mix precommit` is not available from the umbrella or `research_core` app in the current workspace, so verification used `mix format`, targeted corpus tests, and the full `research_core` test suite instead.
