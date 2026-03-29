defmodule ResearchJobs.Retrieval.PipelineSearchAdapterStub do
  @behaviour ResearchJobs.Retrieval.SearchAdapter

  alias ResearchCore.Retrieval.{NormalizedSearchHit, ProviderError, ProviderResult, SearchRequest}

  @impl true
  def search(%SearchRequest{} = request, _opts) do
    record_call(request)

    case Process.get(:pipeline_stub_responses, %{})
         |> Map.fetch!({request.provider, request.query.text}) do
      {:ok, hit_specs} ->
        {:ok,
         %ProviderResult{
           provider: request.provider,
           request: request,
           hits: normalize_hits(request, hit_specs),
           raw_payload: %{"provider" => request.provider, "query" => request.query.text}
         }}

      {:error, reason} ->
        {:error,
         %ProviderError{
           provider: request.provider,
           request_kind: :search,
           reason: reason,
           message: "#{request.provider} failed for #{request.query.text}"
         }}
    end
  end

  defp record_call(request) do
    calls = Process.get(:pipeline_stub_calls, [])

    Process.put(
      :pipeline_stub_calls,
      calls ++ [{request.provider, request.query.text, request.max_results}]
    )
  end

  defp normalize_hits(request, hit_specs) do
    hit_specs
    |> Enum.with_index(1)
    |> Enum.map(fn {hit_spec, rank} ->
      %NormalizedSearchHit{
        provider: request.provider,
        query: request.query,
        rank: rank,
        title: hit_spec.title,
        url: hit_spec.url,
        snippet: Map.get(hit_spec, :snippet),
        raw_payload: hit_spec
      }
    end)
  end
end

defmodule ResearchJobs.Retrieval.PipelineFetchAdapterStub do
  @behaviour ResearchJobs.Retrieval.FetchAdapter

  alias ResearchCore.Retrieval.{FetchRequest, FetchResult, FetchedDocument, ProviderError}

  @impl true
  def fetch(%FetchRequest{} = request, _opts) do
    record_call(request)

    case Process.get(:pipeline_fetch_stub_responses, %{})
         |> Map.fetch!(request.url) do
      {:ok, document_spec} ->
        {:ok,
         %FetchResult{
           request: request,
           status: :ok,
           document: %FetchedDocument{
             url: request.url,
             title: Map.get(document_spec, :title),
             content: Map.fetch!(document_spec, :content),
             content_format: Map.get(document_spec, :content_format, :text),
             raw_payload: document_spec,
             fetched_at: Map.get(document_spec, :fetched_at)
           }
         }}

      {:error, reason} ->
        {:error,
         %ProviderError{
           provider: request.provider,
           request_kind: :fetch,
           reason: reason,
           message: "#{request.provider} failed to fetch #{request.url}"
         }}
    end
  end

  defp record_call(request) do
    calls = Process.get(:pipeline_fetch_stub_calls, [])

    Process.put(
      :pipeline_fetch_stub_calls,
      calls ++
        [{request.provider, request.url, request.source_hit.query.text, request.source_hit.rank}]
    )
  end
end

defmodule ResearchJobs.Retrieval.PipelineTest do
  use ExUnit.Case, async: false

  alias ResearchCore.Branch.SearchQuery

  alias ResearchCore.Retrieval.{
    FetchRequest,
    FetchResult,
    FetchedDocument,
    NormalizedSearchHit,
    ProviderError,
    ProviderResult,
    RetrievalRun,
    SearchRequest
  }

  alias ResearchJobs.Retrieval.{Pipeline, Policy}

  setup do
    Process.delete(:pipeline_stub_calls)
    Process.delete(:pipeline_stub_responses)
    Process.delete(:pipeline_fetch_stub_calls)
    Process.delete(:pipeline_fetch_stub_responses)

    on_exit(fn ->
      Process.delete(:pipeline_stub_calls)
      Process.delete(:pipeline_stub_responses)
      Process.delete(:pipeline_fetch_stub_calls)
      Process.delete(:pipeline_fetch_stub_responses)
    end)

    :ok
  end

  test "stops at the first successful provider for each query and preserves query order" do
    alpha_query = query("alpha calibration")
    beta_query = query("beta calibration")

    stub_responses(%{
      {:serper, alpha_query.text} =>
        {:ok, [%{title: "Alpha Result", url: "https://example.com/alpha"}]},
      {:serper, beta_query.text} =>
        {:ok, [%{title: "Beta Result", url: "https://example.com/beta"}]}
    })

    run =
      pipeline(max_results_per_query: 7)
      |> Pipeline.search([alpha_query, beta_query])

    assert %RetrievalRun{
             id: run_id,
             started_at: %DateTime{} = started_at,
             completed_at: %DateTime{} = completed_at,
             search_requests: [
               %SearchRequest{provider: :serper, query: ^alpha_query, max_results: 7},
               %SearchRequest{provider: :serper, query: ^beta_query, max_results: 7}
             ],
             provider_results: [
               %ProviderResult{
                 provider: :serper,
                 request: %SearchRequest{provider: :serper, query: ^alpha_query, max_results: 7},
                 hits: [
                   %NormalizedSearchHit{
                     provider: :serper,
                     query: ^alpha_query,
                     rank: 1,
                     title: "Alpha Result",
                     url: "https://example.com/alpha",
                     snippet: nil
                   }
                 ]
               },
               %ProviderResult{
                 provider: :serper,
                 request: %SearchRequest{provider: :serper, query: ^beta_query, max_results: 7},
                 hits: [
                   %NormalizedSearchHit{
                     provider: :serper,
                     query: ^beta_query,
                     rank: 1,
                     title: "Beta Result",
                     url: "https://example.com/beta",
                     snippet: nil
                   }
                 ]
               }
             ],
             provider_errors: [],
             fetch_requests: [],
             fetch_results: []
           } = run

    assert is_binary(run_id)
    assert DateTime.compare(completed_at, started_at) in [:eq, :gt]

    assert Process.get(:pipeline_stub_calls) == [
             {:serper, alpha_query.text, 7},
             {:serper, beta_query.text, 7}
           ]
  end

  test "falls back to the next provider when the first provider errors and fallback is enabled" do
    query = query("fallback calibration")

    stub_responses(%{
      {:serper, query.text} => {:error, :timeout},
      {:brave, query.text} =>
        {:ok,
         [%{title: "Brave Result", url: "https://example.com/brave", snippet: "brave snippet"}]}
    })

    run =
      pipeline(
        search_provider_order: [:serper, :brave],
        fallback_enabled: true,
        max_results_per_query: 4
      )
      |> Pipeline.search([query])

    assert %RetrievalRun{
             search_requests: [
               %SearchRequest{provider: :serper, query: ^query, max_results: 4},
               %SearchRequest{provider: :brave, query: ^query, max_results: 4}
             ],
             provider_results: [
               %ProviderResult{
                 provider: :brave,
                 request: %SearchRequest{provider: :brave, query: ^query, max_results: 4},
                 hits: [
                   %NormalizedSearchHit{
                     provider: :brave,
                     query: ^query,
                     rank: 1,
                     title: "Brave Result",
                     url: "https://example.com/brave",
                     snippet: "brave snippet"
                   }
                 ]
               }
             ],
             provider_errors: [
               %ProviderError{
                 provider: :serper,
                 request_kind: :search,
                 reason: :timeout,
                 message: "serper failed for fallback calibration"
               }
             ]
           } = run

    assert Process.get(:pipeline_stub_calls) == [
             {:serper, query.text, 4},
             {:brave, query.text, 4}
           ]
  end

  test "executes source-scoped queries before generic queries while preserving query provenance" do
    generic_query =
      query("prediction market calibration",
        branch_kind: :direct,
        branch_label: "prediction market calibration"
      )

    scoped_query =
      query("site:arxiv.org prediction market calibration",
        scope_type: :source_scoped,
        source_family: :academic_preprints,
        scoped_pattern: "site:arxiv.org",
        branch_kind: :direct,
        branch_label: "prediction market calibration"
      )

    stub_responses(%{
      {:serper, scoped_query.text} =>
        {:ok, [%{title: "Scoped Result", url: "https://example.com/scoped"}]},
      {:serper, generic_query.text} =>
        {:ok, [%{title: "Generic Result", url: "https://example.com/generic"}]}
    })

    run =
      pipeline(search_provider_order: [:serper, :brave], max_results_per_query: 3)
      |> Pipeline.search([generic_query, scoped_query])

    assert Enum.map(run.search_requests, &{&1.provider, &1.query.text, &1.query.scope_type}) == [
             {:serper, scoped_query.text, :source_scoped},
             {:serper, generic_query.text, :generic}
           ]

    assert [
             %ProviderResult{
               provider: :serper,
               request: %SearchRequest{query: ^scoped_query},
               hits: [
                 %NormalizedSearchHit{
                   query: %SearchQuery{
                     scope_type: :source_scoped,
                     source_family: :academic_preprints,
                     scoped_pattern: "site:arxiv.org",
                     branch_kind: :direct,
                     branch_label: "prediction market calibration"
                   }
                 }
               ]
             },
             %ProviderResult{
               provider: :serper,
               request: %SearchRequest{query: ^generic_query},
               hits: [%NormalizedSearchHit{query: %SearchQuery{scope_type: :generic}}]
             }
           ] = run.provider_results

    assert Process.get(:pipeline_stub_calls) == [
             {:serper, scoped_query.text, 3},
             {:serper, generic_query.text, 3}
           ]
  end

  test "does not fall back when fallback is disabled" do
    query = query("no fallback calibration")

    stub_responses(%{
      {:serper, query.text} => {:error, :rate_limited}
    })

    run =
      pipeline(search_provider_order: [:serper, :brave], fallback_enabled: false)
      |> Pipeline.search([query])

    assert %RetrievalRun{
             search_requests: [
               %SearchRequest{provider: :serper, query: ^query, max_results: 5}
             ],
             provider_results: [],
             provider_errors: [
               %ProviderError{
                 provider: :serper,
                 request_kind: :search,
                 reason: :rate_limited,
                 message: "serper failed for no fallback calibration"
               }
             ]
           } = run

    assert Process.get(:pipeline_stub_calls) == [
             {:serper, query.text, 5}
           ]
  end

  test "returns deterministic request, result, and error ordering across mixed outcomes" do
    alpha_query = query("alpha mixed")
    beta_query = query("beta mixed")

    stub_responses(%{
      {:serper, alpha_query.text} => {:error, :http_error},
      {:brave, alpha_query.text} =>
        {:ok, [%{title: "Alpha Brave", url: "https://example.com/alpha-brave"}]},
      {:serper, beta_query.text} =>
        {:ok, [%{title: "Beta Serper", url: "https://example.com/beta-serper"}]}
    })

    run =
      pipeline(
        search_provider_order: [:serper, :brave],
        fallback_enabled: true,
        max_results_per_query: 2
      )
      |> Pipeline.search([alpha_query, beta_query])

    assert Enum.map(run.search_requests, &{&1.provider, &1.query.text, &1.max_results}) == [
             {:serper, alpha_query.text, 2},
             {:brave, alpha_query.text, 2},
             {:serper, beta_query.text, 2}
           ]

    assert Enum.map(run.provider_results, &{&1.provider, &1.request.query.text}) == [
             {:brave, alpha_query.text},
             {:serper, beta_query.text}
           ]

    assert Enum.map(run.provider_errors, &{&1.provider, &1.reason, &1.message}) == [
             {:serper, :http_error, "serper failed for alpha mixed"}
           ]

    assert [
             %NormalizedSearchHit{provider: :brave, query: ^alpha_query, title: "Alpha Brave"},
             %NormalizedSearchHit{provider: :serper, query: ^beta_query, title: "Beta Serper"}
           ] =
             run.provider_results
             |> Enum.flat_map(& &1.hits)

    assert Process.get(:pipeline_stub_calls) == [
             {:serper, alpha_query.text, 2},
             {:brave, alpha_query.text, 2},
             {:serper, beta_query.text, 2}
           ]
  end

  test "fetches selected hits and attaches explicit fetch results when fetch is enabled" do
    query = query("fetch calibration")

    stub_responses(%{
      {:serper, query.text} =>
        {:ok,
         [
           %{title: "Alpha Doc", url: "https://example.com/alpha-doc", snippet: "alpha"},
           %{title: "Beta Doc", url: "https://example.com/beta-doc", snippet: "beta"}
         ]}
    })

    stub_fetch_responses(%{
      "https://example.com/alpha-doc" =>
        {:ok, %{title: "Alpha Fetched", content: "alpha content"}},
      "https://example.com/beta-doc" => {:error, :http_error}
    })

    run =
      pipeline(fetch_enabled: true, fetch_limit_per_query: 2)
      |> Pipeline.search([query])

    assert %RetrievalRun{
             search_requests: [
               %SearchRequest{provider: :serper, query: ^query, max_results: 5}
             ],
             provider_results: [
               %ProviderResult{
                 provider: :serper,
                 hits: [
                   %NormalizedSearchHit{
                     title: "Alpha Doc",
                     url: "https://example.com/alpha-doc",
                     rank: 1,
                     query: ^query,
                     fetch_status: :ok
                   },
                   %NormalizedSearchHit{
                     title: "Beta Doc",
                     url: "https://example.com/beta-doc",
                     rank: 2,
                     query: ^query,
                     fetch_status: :error
                   }
                 ]
               }
             ],
             provider_errors: [
               %ProviderError{
                 provider: :jina,
                 request_kind: :fetch,
                 reason: :http_error,
                 message: "jina failed to fetch https://example.com/beta-doc"
               }
             ],
             fetch_requests: [
               %FetchRequest{
                 provider: :jina,
                 url: "https://example.com/alpha-doc",
                 source_hit: %NormalizedSearchHit{title: "Alpha Doc", rank: 1, query: ^query}
               },
               %FetchRequest{
                 provider: :jina,
                 url: "https://example.com/beta-doc",
                 source_hit: %NormalizedSearchHit{title: "Beta Doc", rank: 2, query: ^query}
               }
             ],
             fetch_results: [
               %FetchResult{
                 request: %FetchRequest{
                   provider: :jina,
                   url: "https://example.com/alpha-doc",
                   source_hit: %NormalizedSearchHit{title: "Alpha Doc", rank: 1, query: ^query}
                 },
                 status: :ok,
                 document: %FetchedDocument{
                   url: "https://example.com/alpha-doc",
                   title: "Alpha Fetched",
                   content: "alpha content",
                   content_format: :text
                 },
                 error: nil
               },
               %FetchResult{
                 request: %FetchRequest{
                   provider: :jina,
                   url: "https://example.com/beta-doc",
                   source_hit: %NormalizedSearchHit{title: "Beta Doc", rank: 2, query: ^query}
                 },
                 status: :error,
                 document: nil,
                 error: %ProviderError{
                   provider: :jina,
                   request_kind: :fetch,
                   reason: :http_error,
                   message: "jina failed to fetch https://example.com/beta-doc"
                 }
               }
             ]
           } = run

    assert Process.get(:pipeline_stub_calls) == [
             {:serper, query.text, 5}
           ]

    assert Process.get(:pipeline_fetch_stub_calls) == [
             {:jina, "https://example.com/alpha-doc", query.text, 1},
             {:jina, "https://example.com/beta-doc", query.text, 2}
           ]
  end

  test "leaves fetch requests and results empty when fetch is disabled" do
    query = query("no fetch calibration")

    stub_responses(%{
      {:serper, query.text} =>
        {:ok, [%{title: "Alpha Result", url: "https://example.com/no-fetch"}]}
    })

    stub_fetch_responses(%{
      "https://example.com/no-fetch" => {:ok, %{title: "Should Not Fetch", content: "ignored"}}
    })

    run =
      pipeline(fetch_enabled: false, fetch_limit_per_query: 1)
      |> Pipeline.search([query])

    assert %RetrievalRun{
             provider_results: [
               %ProviderResult{
                 provider: :serper,
                 hits: [
                   %NormalizedSearchHit{
                     title: "Alpha Result",
                     url: "https://example.com/no-fetch",
                     rank: 1,
                     query: ^query,
                     fetch_status: :not_fetched
                   }
                 ]
               }
             ],
             fetch_requests: [],
             fetch_results: []
           } = run

    assert Process.get(:pipeline_stub_calls) == [
             {:serper, query.text, 5}
           ]

    assert Process.get(:pipeline_fetch_stub_calls, []) == []
  end

  test "applies fetch_limit_per_query to each successful query result set" do
    alpha_query = query("alpha fetch limit")
    beta_query = query("beta fetch limit")

    stub_responses(%{
      {:serper, alpha_query.text} =>
        {:ok,
         [
           %{title: "Alpha 1", url: "https://example.com/alpha-1"},
           %{title: "Alpha 2", url: "https://example.com/alpha-2"}
         ]},
      {:serper, beta_query.text} =>
        {:ok,
         [
           %{title: "Beta 1", url: "https://example.com/beta-1"},
           %{title: "Beta 2", url: "https://example.com/beta-2"}
         ]}
    })

    stub_fetch_responses(%{
      "https://example.com/alpha-1" => {:ok, %{content: "alpha one"}},
      "https://example.com/beta-1" => {:ok, %{content: "beta one"}}
    })

    run =
      pipeline(fetch_enabled: true, fetch_limit_per_query: 1)
      |> Pipeline.search([alpha_query, beta_query])

    assert Enum.map(run.provider_results, fn result ->
             {result.request.query.text,
              Enum.map(result.hits, &{&1.url, &1.rank, &1.fetch_status})}
           end) == [
             {alpha_query.text,
              [
                {"https://example.com/alpha-1", 1, :ok},
                {"https://example.com/alpha-2", 2, :not_fetched}
              ]},
             {beta_query.text,
              [
                {"https://example.com/beta-1", 1, :ok},
                {"https://example.com/beta-2", 2, :not_fetched}
              ]}
           ]

    assert Enum.map(run.fetch_requests, &{&1.url, &1.source_hit.query.text, &1.source_hit.rank}) ==
             [
               {"https://example.com/alpha-1", alpha_query.text, 1},
               {"https://example.com/beta-1", beta_query.text, 1}
             ]

    assert Enum.map(run.fetch_results, &{&1.status, &1.request.url}) == [
             {:ok, "https://example.com/alpha-1"},
             {:ok, "https://example.com/beta-1"}
           ]

    assert Process.get(:pipeline_fetch_stub_calls) == [
             {:jina, "https://example.com/alpha-1", alpha_query.text, 1},
             {:jina, "https://example.com/beta-1", beta_query.text, 1}
           ]
  end

  test "deduplicates exact fetch URLs across query result sets within one retrieval run" do
    alpha_query = query("alpha duplicate fetch")
    beta_query = query("beta duplicate fetch")
    shared_url = "https://example.com/shared-doc"
    alpha_unique_url = "https://example.com/alpha-unique"
    beta_unique_url = "https://example.com/beta-unique"

    stub_responses(%{
      {:serper, alpha_query.text} =>
        {:ok,
         [
           %{title: "Shared Alpha", url: shared_url},
           %{title: "Alpha Unique", url: alpha_unique_url}
         ]},
      {:serper, beta_query.text} =>
        {:ok,
         [
           %{title: "Shared Beta", url: shared_url},
           %{title: "Beta Unique", url: beta_unique_url}
         ]}
    })

    stub_fetch_responses(%{
      shared_url => {:ok, %{title: "Shared Fetched", content: "shared content"}},
      alpha_unique_url => {:ok, %{title: "Alpha Fetched", content: "alpha content"}},
      beta_unique_url => {:ok, %{title: "Beta Fetched", content: "beta content"}}
    })

    run =
      pipeline(fetch_enabled: true, fetch_limit_per_query: 2)
      |> Pipeline.search([alpha_query, beta_query])

    assert Enum.map(run.provider_results, fn result ->
             {result.request.query.text,
              Enum.map(result.hits, &{&1.title, &1.url, &1.fetch_status})}
           end) == [
             {alpha_query.text,
              [
                {"Shared Alpha", shared_url, :ok},
                {"Alpha Unique", alpha_unique_url, :ok}
              ]},
             {beta_query.text,
              [
                {"Shared Beta", shared_url, :ok},
                {"Beta Unique", beta_unique_url, :ok}
              ]}
           ]

    assert Enum.map(run.fetch_requests, &{&1.url, &1.source_hit.title, &1.source_hit.query.text}) ==
             [
               {shared_url, "Shared Alpha", alpha_query.text},
               {alpha_unique_url, "Alpha Unique", alpha_query.text},
               {beta_unique_url, "Beta Unique", beta_query.text}
             ]

    assert Enum.map(run.fetch_results, &{&1.status, &1.request.url, &1.request.source_hit.title}) ==
             [
               {:ok, shared_url, "Shared Alpha"},
               {:ok, alpha_unique_url, "Alpha Unique"},
               {:ok, beta_unique_url, "Beta Unique"}
             ]

    assert Process.get(:pipeline_fetch_stub_calls) == [
             {:jina, shared_url, alpha_query.text, 1},
             {:jina, alpha_unique_url, alpha_query.text, 2},
             {:jina, beta_unique_url, beta_query.text, 2}
           ]
  end

  test "preserves scoped provenance and deduplicates fetches across scoped generic and provider overlap" do
    shared_url = "https://example.com/shared-scope-doc"

    scoped_query =
      query("site:arxiv.org protocol incentive design paper",
        scope_type: :source_scoped,
        source_family: :academic_preprints,
        scoped_pattern: "site:arxiv.org",
        branch_kind: :direct,
        branch_label: "protocol incentive design paper"
      )

    generic_query =
      query("protocol incentive design paper",
        branch_kind: :direct,
        branch_label: "protocol incentive design paper"
      )

    stub_responses(%{
      {:serper, scoped_query.text} => {:ok, [%{title: "Scoped Paper", url: shared_url}]},
      {:serper, generic_query.text} => {:error, :timeout},
      {:brave, generic_query.text} =>
        {:ok, [%{title: "Generic Paper", url: shared_url, snippet: "same url from fallback"}]}
    })

    stub_fetch_responses(%{
      shared_url => {:ok, %{title: "Fetched Shared Paper", content: "paper body"}}
    })

    run =
      pipeline(
        search_provider_order: [:serper, :brave],
        fallback_enabled: true,
        fetch_enabled: true,
        fetch_limit_per_query: 1
      )
      |> Pipeline.search([generic_query, scoped_query])

    assert Enum.map(run.search_requests, &{&1.provider, &1.query.text, &1.query.scope_type}) == [
             {:serper, scoped_query.text, :source_scoped},
             {:serper, generic_query.text, :generic},
             {:brave, generic_query.text, :generic}
           ]

    assert Enum.map(run.provider_results, &{&1.provider, &1.request.query.text, hd(&1.hits).url}) ==
             [
               {:serper, scoped_query.text, shared_url},
               {:brave, generic_query.text, shared_url}
             ]

    assert Enum.map(run.provider_errors, &{&1.provider, &1.request_kind, &1.reason}) == [
             {:serper, :search, :timeout}
           ]

    assert Enum.map(
             run.fetch_requests,
             &{&1.url, &1.source_hit.query.scope_type, &1.source_hit.query.source_family}
           ) == [
             {shared_url, :source_scoped, :academic_preprints}
           ]

    assert [
             %FetchResult{
               status: :ok,
               request: %FetchRequest{
                 url: ^shared_url,
                 source_hit: %NormalizedSearchHit{
                   query: %SearchQuery{
                     scope_type: :source_scoped,
                     source_family: :academic_preprints,
                     scoped_pattern: "site:arxiv.org",
                     branch_kind: :direct,
                     branch_label: "protocol incentive design paper"
                   }
                 }
               }
             }
           ] = run.fetch_results

    assert Enum.map(run.provider_results, fn result ->
             {result.request.query.scope_type,
              Enum.map(
                result.hits,
                &{&1.query.scope_type, &1.query.branch_label, &1.fetch_status}
              )}
           end) == [
             {:source_scoped, [{:source_scoped, "protocol incentive design paper", :ok}]},
             {:generic, [{:generic, "protocol incentive design paper", :ok}]}
           ]

    assert Process.get(:pipeline_fetch_stub_calls) == [
             {:jina, shared_url, scoped_query.text, 1}
           ]
  end

  test "returns an explicit fetch error when no fetch adapter is registered" do
    query = query("missing fetch adapter")

    stub_responses(%{
      {:serper, query.text} =>
        {:ok, [%{title: "Alpha Result", url: "https://example.com/missing-fetch-adapter"}]}
    })

    run =
      pipeline(
        [fetch_enabled: true, fetch_limit_per_query: 1],
        fetch_adapter: nil
      )
      |> Pipeline.search([query])

    assert %RetrievalRun{
             provider_results: [
               %ProviderResult{
                 provider: :serper,
                 hits: [
                   %NormalizedSearchHit{
                     title: "Alpha Result",
                     url: "https://example.com/missing-fetch-adapter",
                     rank: 1,
                     query: ^query,
                     fetch_status: :error
                   }
                 ]
               }
             ],
             fetch_requests: [
               %FetchRequest{
                 provider: :jina,
                 url: "https://example.com/missing-fetch-adapter",
                 source_hit: %NormalizedSearchHit{title: "Alpha Result", rank: 1, query: ^query}
               }
             ],
             fetch_results: [
               %FetchResult{
                 request: %FetchRequest{
                   provider: :jina,
                   url: "https://example.com/missing-fetch-adapter",
                   source_hit: %NormalizedSearchHit{
                     title: "Alpha Result",
                     rank: 1,
                     query: ^query
                   }
                 },
                 status: :error,
                 document: nil,
                 error: %ProviderError{
                   provider: :jina,
                   request_kind: :fetch,
                   reason: :missing_adapter,
                   message: "no fetch adapter is registered for :jina"
                 }
               }
             ]
           } = run

    assert Process.get(:pipeline_fetch_stub_calls, []) == []
  end

  test "surfaces invalid-url, timeout, and rate-limited fetch errors in fetch results and provider errors" do
    query = query("fetch protections")
    invalid_url = "mailto:calibration@example.com"
    timeout_url = "https://example.com/timeout"
    rate_limited_url = "https://example.com/rate-limited"

    stub_responses(%{
      {:serper, query.text} =>
        {:ok,
         [
           %{title: "Invalid URL", url: invalid_url},
           %{title: "Timeout URL", url: timeout_url},
           %{title: "Rate Limited URL", url: rate_limited_url}
         ]}
    })

    stub_fetch_responses(%{
      invalid_url => {:error, :invalid_url},
      timeout_url => {:error, :timeout},
      rate_limited_url => {:error, :rate_limited}
    })

    run =
      pipeline(fetch_enabled: true, fetch_limit_per_query: 3)
      |> Pipeline.search([query])

    assert Enum.map(run.fetch_results, fn result ->
             {result.request.url, result.status, result.error.reason}
           end) == [
             {invalid_url, :error, :invalid_url},
             {timeout_url, :error, :timeout},
             {rate_limited_url, :error, :rate_limited}
           ]

    assert Enum.map(run.provider_errors, &{&1.request_kind, &1.reason, &1.message}) == [
             {:fetch, :invalid_url, "jina failed to fetch #{invalid_url}"},
             {:fetch, :timeout, "jina failed to fetch #{timeout_url}"},
             {:fetch, :rate_limited, "jina failed to fetch #{rate_limited_url}"}
           ]

    assert Enum.map(hd(run.provider_results).hits, &{&1.url, &1.fetch_status}) == [
             {invalid_url, :error},
             {timeout_url, :error},
             {rate_limited_url, :error}
           ]
  end

  defp pipeline(policy_overrides, pipeline_overrides \\ []) do
    policy =
      Policy.new!(
        Keyword.merge(
          [
            search_provider_order: [:serper, :brave, :tavily],
            max_results_per_query: 5,
            fetch_enabled: false
          ],
          policy_overrides
        )
      )

    search_adapters =
      %{
        serper: ResearchJobs.Retrieval.PipelineSearchAdapterStub,
        brave: ResearchJobs.Retrieval.PipelineSearchAdapterStub,
        tavily: ResearchJobs.Retrieval.PipelineSearchAdapterStub
      }
      |> Map.take(policy.search_provider_order)

    Pipeline.new!(
      Keyword.merge(
        [
          policy: policy,
          search_adapters: search_adapters,
          fetch_adapter: ResearchJobs.Retrieval.PipelineFetchAdapterStub
        ],
        pipeline_overrides
      )
    )
  end

  defp query(text, options \\ []) do
    struct!(SearchQuery, Keyword.merge([text: text], options) |> Enum.into(%{}))
  end

  defp stub_responses(responses), do: Process.put(:pipeline_stub_responses, responses)
  defp stub_fetch_responses(responses), do: Process.put(:pipeline_fetch_stub_responses, responses)
end
