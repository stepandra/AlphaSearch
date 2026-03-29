defmodule ResearchJobs.Retrieval.ExaSearchAdapterTest do
  use ExUnit.Case, async: false

  alias ResearchCore.Branch.SearchQuery

  alias ResearchCore.Retrieval.{
    NormalizedSearchHit,
    ProviderError,
    ProviderResult,
    SearchRequest
  }

  alias ResearchJobs.Retrieval.{ExaSearchAdapter, ProviderConfig}

  setup do
    ensure_req_test_ownership_started()
    :ok
  end

  test "builds a basic EXA request and normalizes result hits" do
    query = %SearchQuery{text: "prediction market calibration"}
    request = search_request(query, 2)

    Req.Test.expect(request_test_name(), fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/search"
      assert ["test-exa-key"] == Plug.Conn.get_req_header(conn, "x-api-key")

      assert %{
               "numResults" => 2,
               "query" => "prediction market calibration",
               "type" => "fast"
             } =
               conn
               |> Req.Test.raw_body()
               |> Jason.decode!()

      Req.Test.json(conn, %{
        "requestId" => "req_exa_123",
        "results" => [
          %{
            "id" => "https://example.com/calibration",
            "title" => "Calibration in prediction markets",
            "url" => "https://example.com/calibration",
            "publishedDate" => "2026-03-01T00:00:00Z",
            "author" => "Researcher One",
            "text" => "Empirical study of forecast calibration"
          },
          %{
            "id" => "https://example.com/scoring",
            "title" => "Forecast scoring in markets",
            "url" => "https://example.com/scoring",
            "author" => "Researcher Two"
          }
        ],
        "searchType" => "fast",
        "costDollars" => %{"total" => 0.004},
        "output" => %{"content" => "ignored deep output"}
      })
    end)

    assert {:ok, %ProviderResult{} = result} =
             ExaSearchAdapter.search(
               request,
               api_key: "test-exa-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderResult{
             provider: :exa,
             request: ^request,
             raw_payload: %{
               "requestId" => "req_exa_123",
               "results" => [
                 %{
                   "id" => "https://example.com/calibration",
                   "title" => "Calibration in prediction markets",
                   "url" => "https://example.com/calibration",
                   "publishedDate" => "2026-03-01T00:00:00Z",
                   "author" => "Researcher One",
                   "text" => "Empirical study of forecast calibration"
                 },
                 %{
                   "id" => "https://example.com/scoring",
                   "title" => "Forecast scoring in markets",
                   "url" => "https://example.com/scoring",
                   "author" => "Researcher Two"
                 }
               ],
               "searchType" => "fast",
               "costDollars" => %{"total" => 0.004}
             },
             hits: [
               %NormalizedSearchHit{
                 provider: :exa,
                 query: ^query,
                 rank: 1,
                 title: "Calibration in prediction markets",
                 url: "https://example.com/calibration",
                 snippet: "Empirical study of forecast calibration",
                 raw_payload: %{
                   "id" => "https://example.com/calibration",
                   "title" => "Calibration in prediction markets",
                   "url" => "https://example.com/calibration",
                   "publishedDate" => "2026-03-01T00:00:00Z",
                   "author" => "Researcher One",
                   "text" => "Empirical study of forecast calibration"
                 },
                 fetch_status: :not_fetched
               },
               %NormalizedSearchHit{
                 provider: :exa,
                 query: ^query,
                 rank: 2,
                 title: "Forecast scoring in markets",
                 url: "https://example.com/scoring",
                 snippet: nil,
                 raw_payload: %{
                   "id" => "https://example.com/scoring",
                   "title" => "Forecast scoring in markets",
                   "url" => "https://example.com/scoring",
                   "author" => "Researcher Two"
                 },
                 fetch_status: :not_fetched
               }
             ]
           } = result
  end

  test "clamps EXA numResults to the documented provider max" do
    Req.Test.expect(request_test_name(), fn conn ->
      assert %{
               "numResults" => 100,
               "query" => "prediction market calibration",
               "type" => "fast"
             } =
               conn
               |> Req.Test.raw_body()
               |> Jason.decode!()

      Req.Test.json(conn, %{
        "requestId" => "req_exa_456",
        "results" => [
          %{
            "title" => "Calibration in prediction markets",
            "url" => "https://example.com/calibration"
          }
        ],
        "searchType" => "fast"
      })
    end)

    assert {:ok, %ProviderResult{} = result} =
             ExaSearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 125),
               api_key: "test-exa-key",
               req: req()
             )

    Req.Test.verify!()

    assert [
             %NormalizedSearchHit{
               rank: 1,
               title: "Calibration in prediction markets",
               url: "https://example.com/calibration"
             }
           ] = result.hits
  end

  test "returns an explicit provider error for non-200 EXA responses" do
    Req.Test.expect(request_test_name(), fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(429, Jason.encode!(%{"error" => "Rate limit exceeded"}))
    end)

    assert {:error, %ProviderError{} = error} =
             ExaSearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 1),
               api_key: "test-exa-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderError{
             provider: :exa,
             request_kind: :search,
             reason: :rate_limited,
             status: 429,
             retryable: true,
             message: "Rate limit exceeded",
             raw_payload: %{"error" => "Rate limit exceeded"}
           } = error
  end

  test "returns an explicit provider error for malformed successful payloads" do
    Req.Test.expect(request_test_name(), fn conn ->
      Req.Test.json(conn, %{
        "requestId" => "req_exa_789",
        "results" => [%{"title" => "Missing URL"}],
        "searchType" => "fast"
      })
    end)

    assert {:error, %ProviderError{} = error} =
             ExaSearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 1),
               api_key: "test-exa-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderError{
             provider: :exa,
             request_kind: :search,
             reason: :malformed_payload,
             status: nil,
             retryable: false,
             raw_payload: %{
               "requestId" => "req_exa_789",
               "results" => [%{"title" => "Missing URL"}],
               "searchType" => "fast"
             }
           } = error

    assert error.message =~ "missing title or url"
  end

  defp search_request(query, max_results) do
    %SearchRequest{provider: :exa, query: query, max_results: max_results}
  end

  defp req do
    ProviderConfig.new_request(plug: {Req.Test, request_test_name()})
  end

  defp request_test_name do
    __MODULE__.EXA
  end

  defp ensure_req_test_ownership_started do
    case Process.whereis(Req.Test.Ownership) do
      nil -> start_supervised!({Req.Test.Ownership, name: Req.Test.Ownership})
      _pid -> :ok
    end
  end
end
