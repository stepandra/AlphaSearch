# Patch Query Generation and Retrieval for Source-Scoped Search Optimization

## Objective
Apply a focused patch across the existing query-generation and retrieval layers so that search is more source-aware, more quota-efficient, and less noisy.

This is not a rewrite.
This task must preserve the existing architecture and only add the missing source-scoped search optimization.

The patch must improve both:
1. query generation
2. retrieval execution

## Problem Statement
The current system generates useful branch and query families, but it does not yet enforce strong source-scoped search behavior.

That causes avoidable waste:
- too many generic web queries
- worse precision
- more duplicate/noisy results
- weaker coverage control
- unnecessary search quota burn

For academic and research-oriented retrieval, generic Google-style search alone is not enough.
The system must explicitly generate and prioritize source-scoped queries such as:
- site:arxiv.org
- site:ssrn.com
- site:nber.org
- site:ideas.repec.org
- site:econpapers.repec.org
- site:osf.io
- site:papers.ssrn.com
- site:openreview.net
- site:proceedings.mlr.press
- site:dl.acm.org

The system must also support scoped official-site or docs-first search patterns where appropriate.

## Scope
Patch the existing implementation so that:

### In query generation:
- source-scoped query families exist explicitly
- branch intent influences source targeting
- generated queries include `site:`-scoped variants where appropriate
- preferred source families are attached to branch/query outputs

### In retrieval:
- source-scoped queries are executed before generic web queries
- retrieval preserves source-family provenance
- fallback to generic web search happens only after scoped attempts or according to explicit policy

## Requirements

### Part A — Query Generation Patch
1. Add a new explicit query family kind:
   - `source_scoped`

2. Add an explicit concept of preferred source families, for example:
   - `academic_preprints`
   - `econ_working_papers`
   - `conference_proceedings`
   - `official_docs`
   - `official_sites`
   - `code_repositories`
   - `general_web`

3. Extend branch/query generation so each branch may include:
   - `preferred_source_families`
   - `source_scoped` query families
   - rationale for source targeting

4. Implement source-scoped query templates using `site:`-style scoping where appropriate.

5. At minimum, support these scoped families:

#### Academic / research sources
- `site:arxiv.org`
- `site:ssrn.com`
- `site:papers.ssrn.com`
- `site:nber.org`
- `site:ideas.repec.org`
- `site:econpapers.repec.org`
- `site:osf.io`
- `site:openreview.net`
- `site:proceedings.mlr.press`
- `site:dl.acm.org`

#### Official/project/documentation sources
- `site:github.com`
- `site:readthedocs.io`
- `site:docs.`
- official-site scoping where a branch clearly targets a known venue/project/domain

6. Add intent-to-source mapping rules.
Examples:
- academic paper search -> academic_preprints / econ_working_papers / conference_proceedings first
- economics or market design literature -> NBER / SSRN / RePEc first
- ML / AI / AFT-like research -> arXiv / OpenReview / proceedings first
- protocol or implementation docs -> official_docs / code_repositories first
- venue behavior / fee rules / exchange docs -> official_sites first

7. Keep the generation deterministic and inspectable.
Do not add black-box ranking or embeddings.

### Part B — Retrieval Patch
8. Update retrieval planning/execution so that:
   - `source_scoped` queries are executed before generic web queries
   - provider execution order still respects configured provider priority
   - generic queries are treated as fallback or broadening passes, not as the first move

9. Preserve provenance for:
   - source family
   - whether a query was scoped or generic
   - which scoped pattern generated the query
   - provider used
   - original branch

10. Add simple retrieval policy rules:
   - run scoped queries first
   - stop early if sufficient high-quality scoped coverage is found, if such a policy hook already exists
   - otherwise continue to generic queries
   - do not silently mix scoped and generic results without provenance

11. Ensure exact same URL is not fetched twice in the same retrieval pass even if returned by:
   - multiple providers
   - both scoped and generic queries

### Part C — Documentation and Tests
12. Update documentation so it explicitly states:
   - why source-scoped search exists
   - which source families are supported
   - how intent-to-source mapping works
   - when generic web search is used
   - what this patch improves and what it still does not solve

13. Add tests for:
   - source-scoped query family generation
   - intent-to-source mapping
   - ordering of scoped vs generic query execution
   - provenance preservation
   - exact URL de-duplication across scoped/generic/provider overlap

## Technical Constraints
- This is a patch, not a rewrite.
- Reuse the current branch/query/retrieval structures where possible.
- Do not introduce a generic meta-search abstraction.
- Do not introduce LLM logic.
- Do not introduce embeddings.
- Do not introduce corpus QA, ranking, evidence scoring, or synthesis into this patch.
- Do not use Tavily or Exa advanced features.
- Use only basic search requests for Tavily and Exa.
- Keep provider adapters explicit and boring.

## Provider Rules
- SERPER: generic and scoped web search are allowed
- JINA: fetch / cleaned content retrieval
- BRAVE: generic and scoped web search are allowed
- TAVILY: basic search only
- EXA: basic search only

The patch must not rely on vendor-specific smart-answer modes, research modes, crawl pipelines, or similar black-box features.

## Anti-Goals
- No rewrite of block 2B
- No rewrite of block 3
- No provider-specific magic leaking into domain contracts
- No semantic paper ranking
- No corpus cleaning
- No evidence scoring
- No agentic search wrappers
- No hidden fusion logic

## Deliverables
1. Updated query family generation with `source_scoped`
2. Intent-to-source mapping rules
3. Updated retrieval execution order for scoped-first behavior
4. Provenance updates
5. Tests
6. Documentation patch

## Success Criteria
- [x] `source_scoped` query families exist
- [x] branches can declare preferred source families
- [x] scoped queries are generated using explicit `site:` patterns where appropriate
- [x] retrieval executes scoped queries before generic queries
- [x] scoped/generic/provider provenance is preserved
- [x] duplicate URLs are not fetched twice within a retrieval pass
- [x] tests cover generation, ordering, provenance, and dedupe behavior
- [x] docs explain the new source-scoped behavior clearly
- [x] no corpus QA, ranking, or synthesis logic leaks into this patch

## Checkpoints
- [x] CHECKPOINT_1: Query family model patched
- [x] CHECKPOINT_2: Intent-to-source mapping added
- [x] CHECKPOINT_3: Source-scoped query generation added
- [x] CHECKPOINT_4: Retrieval execution order patched
- [x] CHECKPOINT_5: Provenance extended
- [x] CHECKPOINT_6: URL fetch de-duplication verified across scoped/generic overlap
- [x] CHECKPOINT_7: Tests added
- [x] CHECKPOINT_8: Docs updated

## Status
- [x] CHECKPOINT_1
- [x] CHECKPOINT_2
- [x] CHECKPOINT_3
- [x] CHECKPOINT_4
- [x] CHECKPOINT_5
- [x] CHECKPOINT_6
- [x] CHECKPOINT_7
- [x] CHECKPOINT_8
- [x] TASK_COMPLETE

## Execution Rules
- Make incremental file changes.
- Update the Status section in this file as checkpoints are completed.
- Mark TASK_COMPLETE only when all success criteria are satisfied.
- Do not continue iterating after TASK_COMPLETE is checked.
- Do not claim completion only in prose.
- Prefer surgical changes over structural rewrites.

## Progress Log
<!-- Update during execution -->
- [x] Patch query family model
- [x] Add source-family mapping
- [x] Add scoped query generation
- [x] Patch retrieval execution order
- [x] Extend provenance
- [x] Verify dedupe behavior
- [x] Add tests
- [x] Update docs
- [x] Inspection snapshot (2026-03-29): retrieval currently preserves provider/query provenance and exact fetch URL dedupe, but scoped queries are still metadata-only and the pipeline still executes queries in caller order rather than scoped-first.

## Notes
- This patch answers: "How do we search more efficiently by targeting the right source families first?"
- This patch does not answer: "Which retrieved documents are high-quality?" or "Which evidence survives corpus QA?"
- If the code starts doing evidence evaluation, synthesis, or graph logic, it has crossed the boundary.

## Completion Report
When complete, append a short completion report containing:
1. what was patched
2. what was deliberately left unchanged
3. exact files added or changed
4. example scoped queries generated
5. example retrieval ordering behavior
6. any remaining limitations

### Completion Report

1. What was patched
   - Patched `research_core` query generation so `:source_scoped` families now emit explicit `site:` queries for academic, economics, docs, code-repository, and supported official-site patterns.
   - Patched `SearchQuery` provenance so scoped/generic metadata and originating branch metadata survive into retrieval.
   - Patched `research_jobs` retrieval ordering so `source_scoped` queries execute before generic queries while still respecting per-query provider priority.
   - Verified exact URL fetch dedup across scoped/generic/provider overlap with focused pipeline coverage.

2. What was deliberately left unchanged
   - No corpus QA, evidence scoring, synthesis, semantic reranking, or hidden fusion logic was added.
   - No new meta-search abstraction, embeddings, or provider-specific smart modes were introduced.
   - No early-stop heuristic was added because there was no existing explicit policy hook for that behavior.

3. Exact files added or changed
   - Changed `apps/research_core/lib/research_core/branch/search_query.ex`
   - Changed `apps/research_core/lib/research_core/branch/source_family.ex`
   - Changed `apps/research_core/lib/research_core/branch/query_family_generator.ex`
   - Changed `apps/research_core/test/research_core/branch/structs_test.exs`
   - Changed `apps/research_core/test/research_core/branch/query_family_generator_test.exs`
   - Changed `apps/research_core/test/research_core/branch/search_plan_generator_test.exs`
   - Added `apps/research_core/test/branch_generation_documentation_test.exs`
   - Changed `apps/research_core/test/retriever_source_acquisition_documentation_test.exs`
   - Changed `apps/research_jobs/lib/research_jobs/retrieval/pipeline.ex`
   - Changed `apps/research_jobs/test/research_jobs/retrieval/pipeline_test.exs`
   - Changed `docs/branch_generation.md`
   - Changed `docs/retriever_source_acquisition.md`
   - Changed `PROMPT.md`

4. Example scoped queries generated
   - `site:readthedocs.io order routing public API docs`
   - `site:docs. order routing public API docs`
   - `site:github.com order routing public API docs`
   - `site:arxiv.org protocol incentive design paper scholarly review`
   - `site:openreview.net protocol incentive design paper scholarly review`

5. Example retrieval ordering behavior
   - If the caller passes `[generic_query, scoped_query]`, the pipeline now executes `scoped_query` first.
   - Within that scoped query, provider attempts still follow configured order such as `[:serper, :brave]`.
   - Generic fallback runs afterward, and if both scoped and generic passes surface the same URL, only one fetch is issued for that URL.

6. Remaining limitations
   - Official-site scoped expansion is intentionally limited to the explicit supported domain mappings currently encoded in `SourceFamily`.
   - There is still no explicit retrieval policy hook for stopping early after sufficient scoped coverage.
   - Repo-root `mix precommit` still fails outside this patch because `ResearchStore.Repo` is missing `priv/repo/migrations` in the current workspace.
