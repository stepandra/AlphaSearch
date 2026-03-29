# Branch Generation and Query Families

The branch-generation layer expands a normalized research theme into an explicit, deterministic search plan. It lives in `apps/research_core/lib/research_core/branch/` and is the boundary between theme intake and future retrieval work.

The top-level entrypoint is `ResearchCore.Branch.SearchPlanGenerator.generate/1`. It accepts a `ResearchCore.Theme.Normalized.t()` and returns a list of fully populated `ResearchCore.Branch.Branch.t()` structs.

## Data Structures

| Struct / Enum | Module | Required Fields | Purpose |
|---------------|--------|-----------------|---------|
| `BranchKind` | `ResearchCore.Branch.BranchKind` | n/a | Canonical branch categories |
| `QueryFamilyKind` | `ResearchCore.Branch.QueryFamilyKind` | n/a | Canonical query-family categories |
| `SourceHint` | `ResearchCore.Branch.SourceHint` | `label` | Optional hint about a likely source or venue |
| `SearchQuery` | `ResearchCore.Branch.SearchQuery` | `text` | Explicit generated query text with optional source hints, source-scoping provenance, and originating branch provenance |
| `QueryFamily` | `ResearchCore.Branch.QueryFamily` | `kind`, `rationale` | One search strategy, its generated queries, and optional target source families |
| `Branch` | `ResearchCore.Branch.Branch` | `kind`, `label`, `rationale`, `theme_relation` | One expansion angle over the normalized theme plus preferred source families and source-targeting rationale |

## Pipeline

`SearchPlanGenerator.generate/1` composes three pure steps:

1. `BranchGenerator.generate/1` creates one branch for each supported branch kind.
2. `QueryFamilyGenerator.generate/2` creates one query family for each supported family kind on each branch.
3. `DuplicateSuppression.deduplicate/1` removes exact and simple near-duplicates within each family.

The output is a list of fully populated `Branch` structs that downstream retrieval can inspect without any hidden logic.

## Branch Types

Branch kinds are returned in `BranchKind.all/0` order:

1. `:direct`
   Why it exists: preserve the user-stated theme without reinterpretation.
   Shape: label is `theme.topic`; relation is `"verbatim"`.
2. `:narrower`
   Why it exists: force a tighter sub-problem so retrieval can find focused literature.
   Shape: `"{topic} — {first domain hint | objective | first constraint | specific aspects}"`.
3. `:broader`
   Why it exists: widen the search frame to capture adjacent context and umbrella literature.
   Shape: `"{first domain hint} and {topic}"` or `"general context of {topic}"`.
4. `:analog`
   Why it exists: surface transferable patterns from related domains instead of only direct matches.
   Shape: `"{second domain hint | first mechanism hint | cross-domain} parallels to {topic}"`.
5. `:mechanism`
   Why it exists: isolate the causal or operational mechanism behind the theme.
   Shape: `"{first mechanism hint | mechanisms of objective | underlying mechanisms} in {topic}"`.
6. `:method`
   Why it exists: isolate the analytical method or modeling frame rather than the business topic alone.
   Shape: `"{second mechanism hint | methods constrained by constraint | analytical methods} for {topic}"`.

Every branch includes:

- `kind`
- `label`
- `rationale`
- `theme_relation`
- `query_families`

## Query Family Types

Query family kinds are returned in `QueryFamilyKind.all/0` order:

1. `:precision`
   Why it exists: generate tight queries likely to match directly relevant work.
   Shape: branch label, plus an objective-augmented variant when the theme has an objective.
2. `:recall`
   Why it exists: widen coverage with shorter topic phrases, domain labels, and one mechanism label.
   Shape: first four topic words, optionally combined with up to two domain hints and one mechanism hint.
3. `:synonym_alias`
   Why it exists: make vocabulary differences inspectable instead of assuming one naming convention.
   Shape: domain and mechanism labels combined with topic context, or an explicit `"alternative terminology"` fallback.
4. `:literature_format`
   Why it exists: target academic phrasing patterns that often surface papers, surveys, and working drafts.
   Shape: quoted branch label with `"working paper"` and `"survey review"`, plus an optional objective-driven `"paper"` query.
5. `:venue_specific`
   Why it exists: attach known venue names when the theme suggests them, while preserving a fallback query when it does not.
   Shape: branch label plus inferred venue names such as `Kalshi`, `Polymarket`, `CBOE`, `SSRN`, `NBER`, `arXiv`, `NeurIPS`, `Dune Analytics`, or `Messari`.
6. `:source_scoped`
   Why it exists: make source targeting explicit so downstream retrieval can search academic sites, working-paper hosts, docs venues, or official project sites before broad web search.
   Shape: one `SearchQuery` per supported `site:` pattern, with `scope_type`, `source_family`, `scoped_pattern`, `branch_kind`, and `branch_label` populated for provenance.

Each `QueryFamily` includes:

- `kind`
- `rationale`
- one or more `SearchQuery` structs
- optional `SourceHint` structs attached to individual queries
- optional `source_families` metadata for source-targeted query families

## Source Targeting and Scoped Search

The source-targeting patch exists because generic web search is too noisy for many research workflows. Some themes are better served by explicit source families and canonical `site:` scopes:

- academic literature queries should prefer preprints and proceedings before general web search
- economics or market-design literature should prefer working-paper hosts before generic search
- docs-first protocol or implementation questions should prefer official docs and code repositories before generic search
- venue-rules or exchange-policy questions should prefer official sites before broad web search

Each branch now carries:

- `preferred_source_families`
- `source_targeting_rationale`

Each generated `SearchQuery` now carries:

- `scope_type`
- `source_family`
- `scoped_pattern`
- `branch_kind`
- `branch_label`

Supported source families are currently:

- `academic_preprints`
- `econ_working_papers`
- `conference_proceedings`
- `official_docs`
- `official_sites`
- `code_repositories`
- `general_web`

Canonical scoped patterns currently emitted include:

- `site:arxiv.org`
- `site:ssrn.com`
- `site:papers.ssrn.com`
- `site:osf.io`
- `site:nber.org`
- `site:ideas.repec.org`
- `site:econpapers.repec.org`
- `site:openreview.net`
- `site:proceedings.mlr.press`
- `site:dl.acm.org`
- `site:readthedocs.io`
- `site:docs.`
- `site:github.com`

Known official-site patterns are also emitted when the branch text clearly targets a supported venue or project domain. The current explicit list covers:

- `site:kalshi.com`
- `site:polymarket.com`
- `site:cboe.com`
- `site:dune.com`
- `site:messari.io`

Intent-to-source mapping remains deterministic and inspectable. The current rules are keyword-driven and intentionally boring:

- academic or scholarly wording biases branches toward `academic_preprints` and `conference_proceedings`
- economics and market-design wording biases branches toward `econ_working_papers` first
- machine-learning wording biases branches toward `academic_preprints` and `conference_proceedings`
- docs-oriented wording biases branches toward `official_docs` and `code_repositories`
- venue-rules or exchange-policy wording biases branches toward `official_sites` first
- if no stronger signal is present, the branch falls back to `general_web`

Generic web search still exists in the plan, but it is now explicit fallback or broadening coverage. The branch/query-generation layer does not remove generic queries; it adds deterministic scoped variants so retrieval can try high-precision sources first.

## Duplicate Suppression

`DuplicateSuppression.deduplicate/1` runs within each query family. It suppresses:

- exact string duplicates
- whitespace-normalized duplicates
- case-only duplicates
- simple near-duplicates based on sorted alphanumeric tokens

Suppression is intentionally conservative and inspectable. The first query wins for ordering and representative text. When later duplicates carry additional `SourceHint` values, those hints are merged into the kept query so venue guidance is not lost.

## Guarantees

This block provides these guarantees:

- output is deterministic and pure
- branch order is canonical: `[:direct, :narrower, :broader, :analog, :mechanism, :method]`
- query-family order is canonical: `[:precision, :recall, :synonym_alias, :literature_format, :venue_specific, :source_scoped]`
- every generated search plan returns exactly 6 branches
- every generated branch returns exactly 6 query families
- every non-`source_scoped` family returns at least one explicit `SearchQuery`
- `:source_scoped` returns explicit `site:` queries whenever the branch maps to source families with canonical scoped patterns
- generated query text is normalized so it is trimmed, whitespace-collapsed, and non-blank
- generated scoped queries preserve `scope_type`, `source_family`, `scoped_pattern`, `branch_kind`, and `branch_label`
- duplicate suppression runs inside each family before the plan is returned
- deduplication preserves encounter order and merges unique source hints deterministically
- the entire output is explicit data, not hidden prompt or provider behavior

## What This Patch Improves

This patch improves the search-plan boundary in these ways:

- it reduces quota waste by turning source preferences into explicit scoped queries instead of leaving everything to generic web search
- it makes intent-to-source mapping inspectable on both the branch and query surfaces
- it gives downstream retrieval enough provenance to execute scoped queries first without inventing hidden ranking logic
- it keeps official-docs, code-repository, and supported official-site search patterns first-class for docs-heavy themes

## Still Not Solved

This patch still does not solve:

- corpus QA
- evidence scoring
- synthesis
- semantic reranking
- deciding whether the retrieved documents are actually high quality
- cross-branch search prioritization
- dynamic discovery of arbitrary official domains outside the explicit supported mappings

## What This Block Does Not Do

This block does not:

- call search APIs, paper APIs, or LLMs
- rank branches or choose a best branch
- score queries, venues, or papers
- perform crossover generation
- deduplicate across branches or across query families globally
- retrieve documents
- normalize or deduplicate corpus records
- synthesize evidence or reports
- create embeddings or knowledge-graph edges
- persist anything to a repo or database

## Example

Given a normalized theme shaped like:

```elixir
%ResearchCore.Theme.Normalized{
  original_input: "prediction market calibration using order book state for cheap OTM contracts",
  normalized_text: "prediction market calibration order book state cheap OTM contracts",
  topic: "prediction market calibration",
  domain_hints: [
    %ResearchCore.Theme.DomainHint{label: "prediction markets"},
    %ResearchCore.Theme.DomainHint{label: "options pricing"}
  ],
  mechanism_hints: [
    %ResearchCore.Theme.MechanismHint{label: "order-book state"},
    %ResearchCore.Theme.MechanismHint{label: "liquidity covariates"}
  ],
  objective: %ResearchCore.Theme.Objective{description: "cheap OTM contracts"},
  constraints: [
    %ResearchCore.Theme.Constraint{description: "public data only", kind: :scope}
  ],
  notes: "focus on inspectable calibration workflows"
}
```

`SearchPlanGenerator.generate/1` returns six branches. Example excerpts:

```elixir
[
  %ResearchCore.Branch.Branch{
    kind: :direct,
    label: "prediction market calibration",
    rationale: "Direct exploration of the stated theme",
    theme_relation: "verbatim",
    preferred_source_families: [:general_web],
    source_targeting_rationale:
      "Fallback to general web because no stronger source-targeting intent was detected.",
    query_families: [
      %ResearchCore.Branch.QueryFamily{
        kind: :precision,
        queries: [
          %ResearchCore.Branch.SearchQuery{text: "prediction market calibration"},
          %ResearchCore.Branch.SearchQuery{text: "prediction market calibration cheap OTM contracts"}
        ]
      },
      %ResearchCore.Branch.QueryFamily{
        kind: :venue_specific,
        queries: [
          %ResearchCore.Branch.SearchQuery{
            text: "prediction market calibration Kalshi",
            source_hints: [%ResearchCore.Branch.SourceHint{label: "Kalshi"}]
          },
          %ResearchCore.Branch.SearchQuery{
            text: "prediction market calibration Polymarket",
            source_hints: [%ResearchCore.Branch.SourceHint{label: "Polymarket"}]
          }
        ]
      },
      %ResearchCore.Branch.QueryFamily{
        kind: :source_scoped,
        source_families: [:general_web],
        queries: []
      }
    ]
  },
  %ResearchCore.Branch.Branch{
    kind: :analog,
    label: "options pricing parallels to prediction market calibration",
    theme_relation: "analogy"
  },
  %ResearchCore.Branch.Branch{
    kind: :method,
    label: "liquidity covariates for prediction market calibration",
    theme_relation: "methodology"
  }
]
```

Those example values are representative of the real generator behavior and match the current integration tests.

For a docs-first theme, the same generator now emits explicit scoped variants such as:

```elixir
%ResearchCore.Branch.QueryFamily{
  kind: :source_scoped,
  source_families: [:official_docs, :code_repositories, :official_sites, :general_web],
  queries: [
    %ResearchCore.Branch.SearchQuery{
      text: "site:readthedocs.io order routing public API docs",
      scope_type: :source_scoped,
      source_family: :official_docs,
      scoped_pattern: "site:readthedocs.io",
      branch_kind: :direct,
      branch_label: "order routing"
    },
    %ResearchCore.Branch.SearchQuery{
      text: "site:github.com order routing public API docs",
      scope_type: :source_scoped,
      source_family: :code_repositories,
      scoped_pattern: "site:github.com",
      branch_kind: :direct,
      branch_label: "order routing"
    }
  ]
}
```

## File Inventory

```
apps/research_core/lib/research_core/branch/
├── branch_kind.ex
├── query_family_kind.ex
├── source_hint.ex
├── search_query.ex
├── query_family.ex
├── branch.ex
├── branch_generator.ex
├── query_family_generator.ex
├── duplicate_suppression.ex
└── search_plan_generator.ex

apps/research_core/test/research_core/branch/
├── branch_generator_test.exs
├── structs_test.exs
├── query_family_generator_test.exs
├── duplicate_suppression_test.exs
└── search_plan_generator_test.exs
```

## Deferred Questions For Retrieval Integration

- Should downstream retrieval consume all branch kinds equally, or should later orchestration choose subsets by policy?
- Should venue inference remain static and local, or should later retrieval configuration own a richer venue catalog?
- Should cross-family or cross-branch deduplication happen later, after provider-specific query rewriting is known?
- Should future retrieval attach provenance about which query produced which corpus hit, or should that live in a higher-level run record?
