# Retriever Source Acquisition

The retriever/source-acquisition layer is the explicit boundary between upstream `SearchQuery` generation and later corpus-processing work. It executes provider search requests, normalizes provider responses into shared structs, optionally fetches cleaned page content for selected URLs, and preserves provenance plus explicit errors for downstream inspection.

This block is implemented across:

- `apps/research_core/lib/research_core/retrieval/` for the pure data contract
- `apps/research_jobs/lib/research_jobs/retrieval/` for provider adapters, policy, and orchestration

It is intentionally narrow. It acquires raw sources and fetched page content. It does not decide which sources are good, does not deduplicate corpus records beyond exact fetch suppression inside one run, and does not synthesize answers.

## Supported Providers

| Provider | Role in this block | What it does | What it does not do |
| --- | --- | --- | --- |
| `SERPER` | Primary web search provider | Executes one basic web search request and normalizes `organic` hits into `ProviderResult` / `NormalizedSearchHit` | No answer generation, no fusion logic, no provider-specific ranking outside the adapter |
| `JINA` | Default fetch provider | Fetches one selected URL through Jina Reader and normalizes the cleaned response into `FetchResult` / `FetchedDocument` | No crawl pipeline, no corpus scoring, no hidden post-processing beyond payload normalization |
| `BRAVE` | Fallback web search provider | Executes one plain Brave web search request when earlier providers fail | No blending with earlier providers, no Brave-specific enrichments in the shared contract |
| `TAVILY` | Fallback web search provider | Executes one basic Tavily search request and normalizes `results` into shared hits | No answer mode, no extract mode, no crawl mode, no raw-content enrichment |
| `EXA` | Fallback web search provider | Executes one plain Exa `/search` request and normalizes `results` into shared hits | No answer mode, no contents mode, no deep research or synthesis APIs |

The adapter role split is fixed and explicit:

- `SERPER`: primary search
- `BRAVE`: first fallback search provider
- `TAVILY`: second fallback search provider
- `EXA`: third fallback search provider
- `JINA`: default fetch provider

## Provider Policy

`ResearchJobs.Retrieval.Policy.default/0` resolves its runtime defaults from `ResearchJobs.Retrieval.ProviderConfig`. In the current implementation, the default search order is `[:serper, :brave, :tavily, :exa]` and the default fetch provider is `:jina`.

The policy surface is explicit and small:

- `search_provider_order`: provider priority for search attempts
- `fetch_provider`: fetch provider selected for `FetchRequest`
- `max_results_per_query`: per-provider result cap attached to each `SearchRequest`
- `fallback_enabled`: whether search continues after a provider error
- `fetch_enabled`: whether selected hits are fetched at all
- `fetch_limit_per_query`: maximum number of hits selected from each successful provider result
- `req_options`: shared `Req` options used to build provider requests

The pipeline does not silently invent policy. `Pipeline.search/2` follows the configured provider order, stops at the first successful provider for each query, and only uses later providers when the current one returns an explicit `ProviderError` and fallback is enabled.

## Scoped-First Search Behavior

The retrieval patch adds one explicit ordering rule on top of provider priority: `source_scoped` queries run before generic queries inside the same retrieval pass.

That means:

- the pipeline first partitions incoming `SearchQuery` structs by `scope_type`
- all scoped queries run before generic queries
- provider execution order inside each query still follows `search_provider_order`
- generic queries act as fallback or broadening passes, not as the first move when explicit scoped variants exist

The retrieval contract does not add hidden ranking or early-stop logic. There is currently no additional policy hook that decides scoped coverage is "good enough" and halts the run. If downstream code needs that later, it should be added as an explicit policy surface rather than inferred from provider behavior.

## Basic Search Only Boundaries

"Basic search only" is an implementation rule, not a marketing claim.

For Tavily:

- requests are sent to the basic search endpoint
- the adapter fixes `"search_depth" => "basic"`
- `"include_answer" => false`
- `"include_raw_content" => false`
- `"include_images" => false`
- `"auto_parameters" => false`
- no answer, extract, or crawl features are part of the retrieval contract

For Exa:

- requests go through the plain `/search` endpoint
- the adapter sends `"type" => "fast"` plus the query text and optional `numResults`
- no answer features are used
- no contents expansion is used
- no deep research, agent, or synthesis features are used

These boundaries matter because downstream code should only rely on the shared structs and not on vendor-specific higher-level product behavior.

## Core Contract

The top-level output is `ResearchCore.Retrieval.RetrievalRun`. It keeps the explicit request and response history for one retrieval pass:

| Struct | Purpose |
| --- | --- |
| `RetrievalRun` | Aggregates all `search_requests`, `provider_results`, `provider_errors`, `fetch_requests`, and `fetch_results` for one pass |
| `SearchRequest` | One provider-targeted search attempt for one upstream `SearchQuery` |
| `ProviderResult` | One successful normalized provider response with bounded `raw_payload` |
| `NormalizedSearchHit` | One normalized hit with `provider`, original `query`, provider `rank`, `title`, `url`, optional `snippet`, raw payload fragment, and `fetch_status` |
| `FetchRequest` | One selected URL slated for fetch, tied back to the originating `NormalizedSearchHit` |
| `FetchResult` | Explicit success or failure for one fetch request |
| `FetchedDocument` | Cleaned fetched page content with format, title, optional timestamp, and raw payload subset |
| `ProviderError` | Explicit search or fetch failure with provider name, `request_kind`, reason, retryability, status, and raw payload when available |

`NormalizedSearchHit.fetch_status` starts as `:not_fetched` and is updated by the pipeline to `:ok` or `:error` when a matching fetch is executed.

For the source-scoped patch, downstream code should treat the embedded `SearchQuery` as the authoritative provenance surface. In addition to `text`, it now carries:

- `scope_type`
- `source_family`
- `scoped_pattern`
- `branch_kind`
- `branch_label`

## Guarantees

This block currently provides these guarantees:

- Every search provider attempt is represented by a `SearchRequest`, even when it fails.
- Every successful provider response is normalized into `ProviderResult` plus `NormalizedSearchHit` structs.
- Provider provenance is preserved on every hit: provider name, original query, provider rank, title, URL, optional snippet, and raw payload fragment.
- Scoped query provenance is preserved end-to-end through `SearchRequest`, `ProviderResult`, `NormalizedSearchHit`, and `FetchRequest` because the original `SearchQuery` struct is retained.
- Search failures are not dropped. They are surfaced as `ProviderError` entries in `provider_errors`.
- Fetch failures are not dropped. They are surfaced both in `fetch_results` and in `provider_errors`.
- `provider_errors` keeps search-side errors first, then fetch-side errors in fetch-request order.
- `fetch_results` is always explicit when fetch is enabled; each selected request yields one `FetchResult`.
- When scoped and generic queries coexist in the same run, scoped queries run before generic ones.
- Exact duplicate URLs are fetched at most once within a single retrieval run, even if multiple provider results or multiple queries surface the same URL.
- When duplicate hits share a fetched URL, the resulting fetch outcome is propagated back onto every matching `NormalizedSearchHit.fetch_status`.
- Exact duplicate URLs are fetched at most once even when the overlap crosses scoped queries, generic queries, or multiple providers.
- Invalid URLs, rate limits, transport failures, and timeout-style failures remain explicit structured errors instead of being silently ignored.
- Raw provider payload retention is bounded to small audit-friendly subsets chosen inside each adapter.
- No provider-specific ranking, blending, or fusion logic leaks out of the adapters into the shared contract.

## Non-Goals

This block explicitly does not do any of the following:

- corpus QA
- evidence scoring
- synthesis
- hypothesis extraction
- knowledge-graph construction
- embeddings
- cross-provider result blending
- semantic reranking
- final evidence judgments
- persistence of "good" versus "bad" source decisions

If later code needs any of that behavior, it should consume the acquisition outputs from this block and implement those decisions in a separate stage.

## Example Retrieval Flows

### 1. Search fallback without fetch

If the first provider fails and fallback is enabled, the pipeline records both the failed attempt and the later success:

```elixir
%RetrievalRun{
  search_requests: [
    %SearchRequest{provider: :serper, query: %SearchQuery{text: "fallback calibration"}, max_results: 4},
    %SearchRequest{provider: :brave, query: %SearchQuery{text: "fallback calibration"}, max_results: 4}
  ],
  provider_results: [
    %ProviderResult{
      provider: :brave,
      hits: [
        %NormalizedSearchHit{
          provider: :brave,
          query: %SearchQuery{text: "fallback calibration"},
          rank: 1,
          title: "Brave Result",
          url: "https://example.com/brave",
          snippet: "brave snippet",
          fetch_status: :not_fetched
        }
      ]
    }
  ],
  provider_errors: [
    %ProviderError{
      provider: :serper,
      request_kind: :search,
      reason: :timeout
    }
  ],
  fetch_requests: [],
  fetch_results: []
}
```

This example shows the main contract rule: successful search output and failed search attempts both remain visible in the same `RetrievalRun`.

### 2. Search plus fetch with duplicate-URL suppression

When fetch is enabled, the pipeline selects up to `fetch_limit_per_query` hits from each successful `ProviderResult`, converts them into `FetchRequest` structs, deduplicates exact URLs across the whole run, and then executes the configured fetch path once per unique URL:

```elixir
%RetrievalRun{
  provider_results: [
    %ProviderResult{
      provider: :serper,
      hits: [
        %NormalizedSearchHit{
          provider: :serper,
          url: "https://example.com/",
          title: "Example Domain",
          fetch_status: :ok
        }
      ]
    },
    %ProviderResult{
      provider: :serper,
      hits: [
        %NormalizedSearchHit{
          provider: :serper,
          url: "https://example.com/",
          title: "Example Domain",
          fetch_status: :ok
        }
      ]
    }
  ],
  fetch_requests: [
    %FetchRequest{
      provider: :jina,
      url: "https://example.com/",
      source_hit: %NormalizedSearchHit{provider: :serper, rank: 1}
    }
  ],
  fetch_results: [
    %FetchResult{
      request: %FetchRequest{provider: :jina, url: "https://example.com/"},
      status: :ok,
      document: %FetchedDocument{
        url: "https://example.com/",
        title: "Example Domain",
        content: "...cleaned page text...",
        content_format: :text
      }
    }
  ]
}
```

The key behavior is that duplicate hits still keep their own provenance in `ProviderResult`, but the shared URL only appears once in `fetch_requests` and once in `fetch_results`.

### 3. Fetch-side error remains explicit

When a selected fetch fails, the pipeline does not hide it behind a missing document. The failure remains explicit:

```elixir
%FetchResult{
  request: %FetchRequest{provider: :jina, url: "https://example.com/timeout"},
  status: :error,
  error: %ProviderError{
    provider: :jina,
    request_kind: :fetch,
    reason: :timeout
  }
}
```

The same `ProviderError` also appears in `RetrievalRun.provider_errors`, and any matching hit receives `fetch_status: :error`.

## What Downstream Code Should Assume

Downstream corpus-QA or evidence-selection code can safely assume:

- acquisition results are explicit structs, not provider-specific JSON blobs
- search and fetch errors are preserved rather than silently dropped
- provenance is attached to every normalized hit
- fetch deduplication is limited to exact URL suppression inside one retrieval run
- the block stops at acquisition and does not make quality judgments

Downstream code should not assume:

- that results from different providers were blended together
- that search rank is comparable across providers
- that fetched content has already been cleaned for corpus quality
- that any provider-specific rich feature was used outside the adapter boundary
