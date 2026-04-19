# Build Strategy Spec Builder / Formula & Rules Extractor

## Objective

Implement the strategy-spec extraction layer for the research platform.

This block must:

* consume a finalized corpus snapshot and a validated synthesis artifact
* extract exact and partial formulas from the synthesis and linked evidence
* convert report conclusions into structured strategy candidates
* normalize each candidate into a machine-usable strategy specification
* classify each candidate by readiness for downstream backtesting
* preserve evidence linkage from each strategy spec back to cited records and synthesis sections

This block is only about turning validated synthesis into structured strategy specs.

Do not implement knowledge-graph reasoning, branch scoring, retrieval execution changes, corpus QA logic, or backtest execution in this block.

---

## Context

Previous blocks already provide:

* normalized themes
* branches
* query families
* retrieval runs and normalized hits
* fetched documents
* canonical corpus records
* duplicate groups
* QA decisions
* immutable corpus snapshots / evidence bundles
* validated synthesis runs and persisted report artifacts
* stable citation keys tied to snapshot records
* lineage and provenance query surfaces

The synthesis artifact already contains structured research output such as:

* executive summary
* ranked important papers/findings
* taxonomy
* directly reusable formulas
* open research gaps
* prototype recommendations

The next required step is not vague hypothesis generation.
The next required step is converting validated research into explicit strategy specifications that can be handed to downstream validation and backtesting.

A valid strategy spec must be closer to a research DSL than to prose.
It must make explicit:

* thesis
* signal or rule
* formula(s)
* required features
* required datasets
* execution assumptions
* sizing assumptions
* suggested validation direction
* readiness state

---

## Requirements

### Part A — Strategy Spec Domain Model

1. Define explicit domain structures for:

* strategy_spec
* strategy_candidate
* formula_candidate
* rule_candidate
* evidence_link
* strategy_extraction_run
* strategy_validation_result
* strategy_readiness
* execution_assumption
* feature_requirement
* data_requirement
* validation_hint
* metric_hint

2. Each strategy spec must answer, at minimum:

* what is the strategy thesis?
* what market or domain does it apply to?
* what is the signal or decision rule?
* what formula or rule is used?
* what evidence supports it?
* what assumptions are required?
* what data/features are required?
* how should it be tested?
* what makes it invalid or not yet testable?

3. Support at least these strategy categories:

* calibration_strategy
* execution_strategy
* coherence_arbitrage_strategy
* sizing_strategy
* behavioral_filter_strategy
* analog_transfer_strategy
* market_structure_strategy

### Part B — Inputs and Extraction Scope

4. Implement an input packager that consumes:

* finalized corpus snapshot
* validated synthesis artifact
* synthesis profile metadata where useful
* optional branch/theme context

5. The input packager must expose:

* report sections
* cited record keys and resolved records
* snapshot metadata
* record-level formula availability
* provenance summaries where useful

6. Extraction must only run from validated synthesis artifacts.
   Do not extract from raw provider output that failed synthesis validation.

7. Extraction scope must explicitly include:

* executive summary
* ranked papers / key findings
* taxonomy
* directly reusable formulas
* open research gaps
* prototype recommendations

### Part C — Formula Extraction

8. Implement explicit formula extraction and normalization.

For each extracted formula or rule, capture:

* stable formula ID
* source section(s)
* supporting citation keys
* formula text exactly as available
* whether formula is exact or partial
* symbol glossary if derivable
* formula role:

  * calibration
  * execution
  * arbitrage_or_coherence
  * sizing
  * behavioral_adjustment
  * other

9. Formula rules:

* if the source provides an exact formula, preserve it exactly
* if the source only says a formula exists but does not provide the exact text, mark it as partial and blocked
* do not fabricate missing equations
* preserve uncertainty explicitly

10. Add validation rules:

* exact formulas must cite at least one real supporting record
* partial formulas must be marked partial
* unknown citation keys invalidate the candidate
* formulas without provenance must be rejected

### Part D — Strategy Candidate Extraction

11. Implement extraction of strategy candidates from the validated report.

Each candidate should capture fields conceptually equivalent to:

* stable ID
* title
* thesis
* category
* market_or_domain_applicability
* direct signal or rule
* entry_condition
* exit_condition
* formula references
* required features
* required datasets
* execution assumptions
* sizing assumptions
* evidence references
* conflicting or cautionary evidence
* expected edge source
* validation hints
* candidate metrics
* falsification idea
* readiness status
* notes

12. Each strategy candidate must distinguish between:

* directly specified strategy
* formula-backed but incomplete strategy
* analog transfer candidate
* speculative idea not yet backtestable

13. Add explicit readiness states such as:

* ready_for_backtest
* needs_feature_build
* needs_formula_completion
* needs_data_mapping
* reject

14. Add explicit evidence strength fields such as:

* strong
* moderate
* weak
* speculative

15. Add explicit actionability fields such as:

* immediate
* near_term
* exploratory
* background_only

### Part E — Extraction Logic

16. Implement extraction logic that turns report text into normalized strategy specs.

At minimum, support:

* extracting formula-backed candidate strategies
* extracting rule-based candidate strategies
* linking each strategy to cited evidence
* linking formulas to strategy candidates
* merging near-duplicate candidates
* rejecting narrative filler that does not imply a testable strategy

17. The extraction logic should be explicit and inspectable.
    Do not hide the whole process inside a giant opaque prompt.

18. Use an LLM only behind a narrow provider boundary, and only for:

* formula candidate extraction
* strategy candidate extraction
* structured normalization into intermediate machine-readable output

19. Deterministic post-processing must:

* reject unsupported candidates
* reject phantom citations
* reject candidates with no testable rule/formula and no explicit data path
* downgrade analog-only candidates
* collapse semantically overlapping candidates where practical

### Part F — Strategy Validation

20. Implement validation rules for strategy specs.

At minimum validate:

* required fields are present
* supporting citation keys resolve to the snapshot
* every strategy has either:

  * at least one exact formula
  * or at least one explicit decision rule
* readiness status is present
* evidence strength is present
* directly specified strategies are not labeled speculative
* analog-transfer strategies are labeled analog_transfer
* blocked candidates are not mislabeled ready_for_backtest

21. Preserve caution and limitations.
    If the report includes important warnings or external-validity limits, carry them into the strategy spec.

### Part G — Persistence and Query Surfaces

22. Extend persistence for:

* strategy extraction runs
* formula candidates
* strategy artifacts
* persisted strategy specs
* strategy-to-citation links
* strategy-to-formula links
* strategy-to-report links

23. Each persisted strategy spec must be linked to:

* source synthesis run
* source synthesis artifact
* source corpus snapshot
* source branch/theme context where derivable

24. Add query surfaces for:

* strategies by synthesis run
* strategies by snapshot
* latest strategies for a branch/theme
* strategies by readiness
* strategies by category
* formulas by strategy
* one strategy with full support and provenance
* all `ready_for_backtest` strategies for downstream packaging

### Part H — Output Shape for Next Block

25. The strategy layer must output stable machine-usable specs suitable for the next block.

At minimum, each ready or near-ready strategy spec must expose:

* thesis
* signal_or_rule
* formula references
* feature requirements
* data requirements
* execution assumptions
* sizing assumptions
* candidate metrics
* falsification idea
* readiness status

26. This block may suggest validation directions, but must not build executable backtest plans yet.

### Part I — Documentation and Tests

27. Add tests for:

* extraction from validated synthesis
* formula extraction correctness
* exact vs partial formula handling
* evidence linkage correctness
* duplicate suppression
* readiness classification
* rejection of unsupported candidates
* persistence and reload of strategy artifacts
* query surfaces
* failure behavior for invalid citations or malformed extraction output

28. Add developer documentation explaining:

* what a strategy spec is
* how it differs from synthesis text
* how formulas are represented
* what makes a strategy backtest-ready vs blocked
* how evidence linkage works
* what this block explicitly does not do
* how the next backtest-spec block should consume strategy specs

---

## Technical Specifications

* Implement primarily in `research_core` and `research_jobs`
* Extend `research_store` only where persistence/query support is needed
* Reuse synthesis artifacts and snapshot registry APIs rather than bypassing them
* Use Ecto and Postgres for persisted metadata
* Use ExUnit for tests
* Use Mox only if genuinely useful for the external extraction-provider boundary

---

## Libraries To Use

Use these libraries unless there is a strong concrete reason not to:

* `:instructor`

  * use as the primary LLM structured-output wrapper
  * define response models as Ecto-backed embedded schemas or equivalent changeset-validated schemas
  * use it for formula extraction and strategy-candidate extraction only

* `:req`

  * use as the HTTP transport layer where needed
  * use for any provider integrations or narrow custom adapters if required

* `:nimble_options`

  * use for validating provider config, model config, profile config, retry config, and extraction options

* `:mox`

  * use for mocking the external extraction-provider boundary in tests

* `:stream_data`

  * use for property tests on citation validation, duplicate suppression, readiness invariants, and unsupported-candidate rejection

* `:oban`

  * reuse the existing job orchestration layer for extraction runs
  * do not turn it into a general-purpose streaming bus

* `:ecto`

  * use for schemas, embedded schemas where appropriate, changesets, and persistence

* `:jason` only if already required by existing dependencies

  * do not add JSON abstraction theatre
  * prefer simple explicit encoding/decoding where needed

Do not introduce:

* `:langchain`
* graph databases
* generic prompt engines
* agent frameworks
* CQRS or event-sourcing ceremony
* a generic artifact engine

---

## Library and Implementation Rules

* Prefer explicit structs and explicit extraction modules
* Prefer deterministic normalization after any provider-assisted extraction
* Keep provider boundaries narrow
* Keep formula provenance first-class
* Keep evidence linkage first-class
* Prefer boring inspectable heuristics over fake intelligence
* Store raw extraction output separately from validated normalized artifacts if helpful
* Use Instructor response models plus changeset validation instead of free-form JSON parsing where practical
* Do not let provider-specific response shapes leak across the boundary

---

## Constraints

* Do not re-run retrieval
* Do not re-run corpus QA
* Do not mutate finalized snapshots
* Do not mutate validated synthesis artifacts
* Do not build knowledge-graph reasoning
* Do not score branches
* Do not package or execute backtests
* Do not silently collapse uncertainty into fake precision
* Do not fabricate formulas

---

## Anti-Goals

* No KG reasoning
* No branch exploration policy
* No backtest execution
* No live trading logic
* No generic reasoning engine
* No graph DB
* No hidden provider magic
* No fabricated evidence or formulas

---

## Deliverables

1. Strategy-spec domain structs/modules
2. Input packager from synthesis + snapshot
3. Formula extraction and normalization flow
4. Strategy candidate extraction and normalization flow
5. Validation rules for strategy specs
6. Persistence for extraction runs, formulas, and strategy specs
7. Query surfaces for downstream consumers
8. Tests and fixtures
9. Documentation and examples

---

## Success Criteria

* [x] A validated synthesis artifact can be converted into structured strategy specs
* [x] Exact and partial formulas are extracted and labeled correctly
* [x] Every accepted strategy links back to real snapshot evidence
* [x] Strategy specs are categorized explicitly
* [x] Readiness for downstream backtesting is explicit
* [x] Unsupported or phantom-cited strategies are rejected
* [x] Near-duplicate strategy candidates are collapsed predictably
* [x] Strategy artifacts are persisted and reloadable
* [x] Downstream code can load `ready_for_backtest` strategies by snapshot, report, branch, and category
* [x] No KG, branch scoring, or backtest execution logic leaks into this block

---

## Checkpoints

* [x] CHECKPOINT_1: Strategy structs defined
* [x] CHECKPOINT_2: Input packager implemented
* [x] CHECKPOINT_3: Formula extraction implemented
* [x] CHECKPOINT_4: Strategy extraction implemented
* [x] CHECKPOINT_5: Validation rules implemented
* [x] CHECKPOINT_6: Duplicate suppression / grouping implemented
* [x] CHECKPOINT_7: Persistence implemented
* [x] CHECKPOINT_8: Query surfaces implemented
* [x] CHECKPOINT_9: Tests added
* [x] CHECKPOINT_10: Docs completed

## Status

* [x] CHECKPOINT_1
* [x] CHECKPOINT_2
* [x] CHECKPOINT_3
* [x] CHECKPOINT_4
* [x] CHECKPOINT_5
* [x] CHECKPOINT_6
* [x] CHECKPOINT_7
* [x] CHECKPOINT_8
* [x] CHECKPOINT_9
* [x] CHECKPOINT_10
* [x] TASK_COMPLETE

---

## Execution Rules

* Make incremental file changes.
* Update the Status section in this file as checkpoints are completed.
* Mark TASK_COMPLETE only when all success criteria are satisfied.
* Do not continue iterating after TASK_COMPLETE is checked.
* Do not claim completion only in prose.
* Prefer explicit strategy structs and validators over broad abstractions.
* If extraction output fails validation, persist the failed run and validation reasons rather than papering over it.

---

## Progress Log

<!-- Update during execution -->

* [x] Define strategy structs and modules
* [x] Implement synthesis-to-strategy input packaging
* [x] Implement formula extraction
* [x] Implement strategy extraction
* [x] Implement validation
* [x] Implement duplicate suppression
* [x] Implement persistence
* [x] Implement query surfaces
* [x] Add tests
* [x] Add docs

---

## Notes

* This block answers: "What concrete, evidence-linked, formula-aware strategy specs can we extract from a validated research report?"
* This block does not answer: "Which branch should we research next?" or "How do we execute the backtest?"
* If the code starts building a graph, ranking branches, or running experiments, it has crossed the boundary.
* The main guardrail is formula and evidence provenance.
* The second guardrail is readiness classification: not every extracted idea is actually backtestable.

---

## Completion Report

When complete, append a short completion report containing:

1. what was implemented
2. what was deliberately deferred
3. exact files added or changed
4. example strategy spec shape
5. example formula candidate shape
6. example rejected candidate shape
7. remaining limitations

---

The orchestrator will continue iterations until all success criteria are met or limits are reached.

## Completion Report

1. Implemented a full strategy-spec extraction layer across `research_core`, `research_jobs`, and `research_store`: validated synthesis input packaging, formula normalization, strategy candidate normalization, duplicate suppression, readiness/actionability classification, persistence, and downstream query surfaces.
2. Kept the provider boundary narrow and inspectable: deterministic fake/stub providers remain for tests, and a live Instructor-backed strategy provider can now run against configured credentials without changing downstream normalization or persistence behavior.
3. Exact files added or changed:
   - `PROMPT.md`
   - `apps/research_core/lib/research_core/strategy.ex`
   - `apps/research_core/lib/research_core/strategy/*.ex`
   - `apps/research_core/test/research_core/strategy/strategy_pipeline_test.exs`
   - `apps/research_jobs/mix.exs`
   - `apps/research_jobs/lib/research_jobs/strategy/provider.ex`
   - `apps/research_jobs/lib/research_jobs/strategy/provider_error.ex`
   - `apps/research_jobs/lib/research_jobs/strategy/provider_response.ex`
   - `apps/research_jobs/lib/research_jobs/strategy/prompt_builder.ex`
   - `apps/research_jobs/lib/research_jobs/strategy/runner.ex`
   - `apps/research_jobs/lib/research_jobs/strategy/providers/fake.ex`
   - `apps/research_jobs/lib/research_jobs/strategy/providers/stub.ex`
   - `apps/research_jobs/lib/research_jobs/strategy/models/*.ex`
   - `apps/research_jobs/test/research_jobs/strategy/runner_test.exs`
   - `apps/research_jobs/test/research_jobs/strategy/documentation_test.exs`
   - `apps/research_store/lib/research_store.ex`
   - `apps/research_store/lib/research_store/strategy_registry.ex`
   - `apps/research_store/lib/research_store/artifacts/strategy_extraction_run.ex`
   - `apps/research_store/lib/research_store/artifacts/strategy_validation_result.ex`
   - `apps/research_store/lib/research_store/artifacts/strategy_formula_candidate.ex`
   - `apps/research_store/lib/research_store/artifacts/strategy_spec.ex`
   - `apps/research_store/priv/repo/migrations/20260330114622_add_strategy_extraction_registry_tables.exs`
   - `apps/research_store/test/research_store/strategy_registry_test.exs`
   - `docs/strategy_spec_builder.md`
   - `mix.lock`
4. Example strategy spec shape:
   ```elixir
   %ResearchCore.Strategy.StrategySpec{
     id: "strategy_spec_123",
     title: "Calibration Gate",
     thesis: "Trade only when calibration exceeds the venue baseline.",
     category: :calibration_strategy,
     readiness: :ready_for_backtest,
     actionability: :immediate,
     formula_ids: ["formula_candidate_123"],
     decision_rule: %{
       signal_or_rule: "enter when score > 0.62",
       entry_condition: "score > 0.62",
       exit_condition: "score < 0.55",
       formula_ids: ["formula_candidate_123"],
       rule_ids: ["rule_candidate_123"]
     }
   }
   ```
5. Example formula candidate shape:
   ```elixir
   %ResearchCore.Strategy.FormulaCandidate{
     id: "formula_candidate_123",
     formula_text: "score = wins / total",
     exact?: true,
     partial?: false,
     blocked?: false,
     role: :calibration,
     supporting_citation_keys: ["REC_0001"]
   }
   ```
6. Example rejected candidate shape:
   ```elixir
   %{
     type: :unknown_citation_key,
     severity: :fatal,
     message: "strategy candidate references unknown citation keys: REC_9999",
     details: %{unknown_keys: ["REC_9999"]}
   }
   ```
7. Remaining limitations:
   - the strategy provider is now live-capable through Instructor, but provider prompt tuning and environment-specific adapter selection remain intentionally narrow
   - strategy extraction currently relies on deterministic post-processing of provider output rather than a second-stage human review workflow
   - query surfaces return persisted specs/formulas, but no UI or LiveView inspection surface was added in this block

LOOP_COMPLETE
