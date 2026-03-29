defmodule ResearchCore.Retrieval.StructsTest do
  use ExUnit.Case, async: true

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

  describe "RetrievalRun" do
    test "creates with required id and deterministic defaults" do
      run = %RetrievalRun{id: "run-001"}

      assert %RetrievalRun{
               id: "run-001",
               search_requests: [],
               provider_results: [],
               provider_errors: [],
               fetch_requests: [],
               fetch_results: [],
               started_at: nil,
               completed_at: nil
             } = run
    end

    test "rejects creation without id via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(RetrievalRun, %{})
      end
    end
  end

  describe "SearchRequest" do
    test "creates with provider, original query, and optional max_results" do
      request = %SearchRequest{
        provider: :serper,
        query: %SearchQuery{text: "prediction market calibration"},
        max_results: 5
      }

      assert %SearchRequest{
               provider: :serper,
               query: %SearchQuery{text: "prediction market calibration"},
               max_results: 5
             } = request
    end

    test "rejects creation without provider via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(SearchRequest, %{query: %SearchQuery{text: "test"}})
      end
    end

    test "rejects creation without query via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(SearchRequest, %{provider: :serper})
      end
    end
  end

  describe "NormalizedSearchHit" do
    test "creates with required provenance and explicit defaults" do
      hit = %NormalizedSearchHit{
        provider: :serper,
        query: %SearchQuery{text: "prediction market calibration"},
        rank: 1,
        title: "Calibration in prediction markets",
        url: "https://example.com/calibration"
      }

      assert %NormalizedSearchHit{
               provider: :serper,
               query: %SearchQuery{text: "prediction market calibration"},
               rank: 1,
               title: "Calibration in prediction markets",
               url: "https://example.com/calibration",
               snippet: nil,
               raw_payload: nil,
               fetch_status: :not_fetched
             } = hit
    end

    test "creates with snippet, raw payload, and fetch status" do
      hit = %NormalizedSearchHit{
        provider: :brave,
        query: %SearchQuery{text: "order book state calibration"},
        rank: 2,
        title: "Order book state and contract calibration",
        url: "https://example.com/order-book",
        snippet: "A study of order book state",
        raw_payload: %{"age" => "2d"},
        fetch_status: :fetched
      }

      assert hit.snippet == "A study of order book state"
      assert hit.raw_payload == %{"age" => "2d"}
      assert hit.fetch_status == :fetched
    end

    test "rejects creation without provider via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(NormalizedSearchHit, %{
          query: %SearchQuery{text: "test"},
          rank: 1,
          title: "Title",
          url: "https://example.com"
        })
      end
    end

    test "rejects creation without query via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(NormalizedSearchHit, %{
          provider: :serper,
          rank: 1,
          title: "Title",
          url: "https://example.com"
        })
      end
    end

    test "rejects creation without rank via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(NormalizedSearchHit, %{
          provider: :serper,
          query: %SearchQuery{text: "test"},
          title: "Title",
          url: "https://example.com"
        })
      end
    end

    test "rejects creation without title via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(NormalizedSearchHit, %{
          provider: :serper,
          query: %SearchQuery{text: "test"},
          rank: 1,
          url: "https://example.com"
        })
      end
    end

    test "rejects creation without url via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(NormalizedSearchHit, %{
          provider: :serper,
          query: %SearchQuery{text: "test"},
          rank: 1,
          title: "Title"
        })
      end
    end
  end

  describe "ProviderResult" do
    test "creates with request, normalized hits, and raw payload" do
      request = %SearchRequest{
        provider: :serper,
        query: %SearchQuery{text: "prediction market calibration"},
        max_results: 10
      }

      hit = %NormalizedSearchHit{
        provider: :serper,
        query: %SearchQuery{text: "prediction market calibration"},
        rank: 1,
        title: "Calibration in prediction markets",
        url: "https://example.com/calibration"
      }

      result = %ProviderResult{
        provider: :serper,
        request: request,
        hits: [hit],
        raw_payload: %{"organic" => [%{"title" => "Calibration in prediction markets"}]}
      }

      assert %ProviderResult{
               provider: :serper,
               request: %SearchRequest{provider: :serper, max_results: 10},
               hits: [%NormalizedSearchHit{rank: 1}],
               raw_payload: %{"organic" => [%{"title" => "Calibration in prediction markets"}]}
             } = result
    end

    test "defaults hits to an empty list" do
      result = %ProviderResult{
        provider: :exa,
        request: %SearchRequest{provider: :exa, query: %SearchQuery{text: "cross exchange alpha"}}
      }

      assert result.hits == []
      assert result.raw_payload == nil
    end

    test "rejects creation without provider via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(ProviderResult, %{
          request: %SearchRequest{provider: :serper, query: %SearchQuery{text: "test"}}
        })
      end
    end

    test "rejects creation without request via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(ProviderResult, %{provider: :serper})
      end
    end
  end

  describe "FetchedDocument" do
    test "creates with required page content fields and optional metadata" do
      document = %FetchedDocument{
        url: "https://example.com/calibration",
        content: "# Calibration\n\nUseful cleaned markdown",
        content_format: :markdown,
        title: "Calibration",
        raw_payload: %{"content" => "Useful cleaned markdown"}
      }

      assert %FetchedDocument{
               url: "https://example.com/calibration",
               content: "# Calibration\n\nUseful cleaned markdown",
               content_format: :markdown,
               title: "Calibration",
               raw_payload: %{"content" => "Useful cleaned markdown"},
               fetched_at: nil
             } = document
    end

    test "rejects creation without url via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(FetchedDocument, %{content: "body", content_format: :text})
      end
    end

    test "rejects creation without content via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(FetchedDocument, %{url: "https://example.com", content_format: :text})
      end
    end

    test "rejects creation without content_format via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(FetchedDocument, %{url: "https://example.com", content: "body"})
      end
    end
  end

  describe "ProviderError" do
    test "creates an explicit provider error with safe defaults" do
      error = %ProviderError{
        provider: :jina,
        request_kind: :fetch,
        reason: :timeout
      }

      assert %ProviderError{
               provider: :jina,
               request_kind: :fetch,
               reason: :timeout,
               message: nil,
               status: nil,
               retryable: false,
               raw_payload: nil
             } = error
    end

    test "creates with HTTP status, message, retryable flag, and raw payload" do
      error = %ProviderError{
        provider: :brave,
        request_kind: :search,
        reason: :rate_limited,
        message: "retry later",
        status: 429,
        retryable: true,
        raw_payload: %{"error" => "Too Many Requests"}
      }

      assert error.status == 429
      assert error.retryable
      assert error.raw_payload == %{"error" => "Too Many Requests"}
    end

    test "rejects creation without provider via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(ProviderError, %{request_kind: :search, reason: :timeout})
      end
    end

    test "rejects creation without request_kind via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(ProviderError, %{provider: :serper, reason: :timeout})
      end
    end

    test "rejects creation without reason via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(ProviderError, %{provider: :serper, request_kind: :search})
      end
    end
  end

  describe "FetchRequest" do
    test "creates with provider, target url, and source hit provenance" do
      hit = %NormalizedSearchHit{
        provider: :serper,
        query: %SearchQuery{text: "prediction market calibration"},
        rank: 1,
        title: "Calibration in prediction markets",
        url: "https://example.com/calibration"
      }

      request = %FetchRequest{
        provider: :jina,
        url: "https://example.com/calibration",
        source_hit: hit
      }

      assert %FetchRequest{
               provider: :jina,
               url: "https://example.com/calibration",
               source_hit: %NormalizedSearchHit{provider: :serper, rank: 1}
             } = request
    end

    test "rejects creation without provider via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(FetchRequest, %{
          url: "https://example.com/calibration",
          source_hit: %NormalizedSearchHit{
            provider: :serper,
            query: %SearchQuery{text: "test"},
            rank: 1,
            title: "Title",
            url: "https://example.com"
          }
        })
      end
    end

    test "rejects creation without url via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(FetchRequest, %{
          provider: :jina,
          source_hit: %NormalizedSearchHit{
            provider: :serper,
            query: %SearchQuery{text: "test"},
            rank: 1,
            title: "Title",
            url: "https://example.com"
          }
        })
      end
    end

    test "rejects creation without source_hit via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(FetchRequest, %{provider: :jina, url: "https://example.com/calibration"})
      end
    end
  end

  describe "FetchResult" do
    test "creates a successful fetch result with a nested document" do
      request = %FetchRequest{
        provider: :jina,
        url: "https://example.com/calibration",
        source_hit: %NormalizedSearchHit{
          provider: :serper,
          query: %SearchQuery{text: "prediction market calibration"},
          rank: 1,
          title: "Calibration in prediction markets",
          url: "https://example.com/calibration"
        }
      }

      document = %FetchedDocument{
        url: "https://example.com/calibration",
        content: "Useful cleaned text",
        content_format: :text
      }

      result = %FetchResult{
        request: request,
        status: :ok,
        document: document
      }

      assert %FetchResult{
               request: %FetchRequest{provider: :jina},
               status: :ok,
               document: %FetchedDocument{content_format: :text},
               error: nil
             } = result
    end

    test "creates an error fetch result with explicit provider error" do
      request = %FetchRequest{
        provider: :jina,
        url: "https://example.com/calibration",
        source_hit: %NormalizedSearchHit{
          provider: :serper,
          query: %SearchQuery{text: "prediction market calibration"},
          rank: 1,
          title: "Calibration in prediction markets",
          url: "https://example.com/calibration"
        }
      }

      error = %ProviderError{
        provider: :jina,
        request_kind: :fetch,
        reason: :invalid_url,
        message: "unsupported scheme"
      }

      result = %FetchResult{
        request: request,
        status: :error,
        error: error
      }

      assert %FetchResult{
               request: %FetchRequest{provider: :jina},
               status: :error,
               document: nil,
               error: %ProviderError{reason: :invalid_url}
             } = result
    end

    test "rejects creation without request via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(FetchResult, %{status: :ok})
      end
    end

    test "rejects creation without status via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(FetchResult, %{
          request: %FetchRequest{
            provider: :jina,
            url: "https://example.com/calibration",
            source_hit: %NormalizedSearchHit{
              provider: :serper,
              query: %SearchQuery{text: "test"},
              rank: 1,
              title: "Title",
              url: "https://example.com"
            }
          }
        })
      end
    end
  end
end
