defmodule ResearchJobs.Retrieval.BraveSearchAdapterTest do
  use ExUnit.Case, async: false

  alias ResearchCore.Branch.SearchQuery

  alias ResearchCore.Retrieval.{
    NormalizedSearchHit,
    ProviderError,
    ProviderResult,
    SearchRequest
  }

  alias ResearchJobs.Retrieval.{BraveSearchAdapter, ProviderConfig}

  setup do
    ensure_req_test_ownership_started()
    :ok
  end

  test "builds a basic BRAVE request and normalizes web hits" do
    query = %SearchQuery{text: "prediction market calibration"}
    request = search_request(query, 2)

    Req.Test.expect(request_test_name(), fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.method == "GET"
      assert conn.request_path == "/res/v1/web/search"
      assert ["test-brave-key"] == Plug.Conn.get_req_header(conn, "x-subscription-token")

      assert %{"count" => "2", "q" => "prediction market calibration"} = conn.query_params

      Req.Test.json(conn, %{
        "type" => "search",
        "query" => %{
          "original" => "prediction market calibration",
          "more_results_available" => false
        },
        "web" => %{
          "type" => "search",
          "results" => [
            %{
              "type" => "search_result",
              "title" => "Calibration in prediction markets",
              "url" => "https://example.com/calibration",
              "description" => "Empirical study of forecast calibration",
              "page_age" => "2026-03-01T00:00:00"
            },
            %{
              "type" => "search_result",
              "title" => "Forecast scoring in markets",
              "url" => "https://example.com/scoring",
              "description" => "Scoring-rule implications for traders"
            }
          ]
        },
        "videos" => %{"results" => []}
      })
    end)

    assert {:ok, %ProviderResult{} = result} =
             BraveSearchAdapter.search(
               request,
               api_key: "test-brave-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderResult{
             provider: :brave,
             request: ^request,
             raw_payload: %{
               "query" => %{
                 "original" => "prediction market calibration",
                 "more_results_available" => false
               },
               "web" => %{
                 "results" => [
                   %{
                     "type" => "search_result",
                     "title" => "Calibration in prediction markets",
                     "url" => "https://example.com/calibration",
                     "description" => "Empirical study of forecast calibration",
                     "page_age" => "2026-03-01T00:00:00"
                   },
                   %{
                     "type" => "search_result",
                     "title" => "Forecast scoring in markets",
                     "url" => "https://example.com/scoring",
                     "description" => "Scoring-rule implications for traders"
                   }
                 ]
               }
             },
             hits: [
               %NormalizedSearchHit{
                 provider: :brave,
                 query: ^query,
                 rank: 1,
                 title: "Calibration in prediction markets",
                 url: "https://example.com/calibration",
                 snippet: "Empirical study of forecast calibration",
                 raw_payload: %{
                   "type" => "search_result",
                   "title" => "Calibration in prediction markets",
                   "url" => "https://example.com/calibration",
                   "description" => "Empirical study of forecast calibration",
                   "page_age" => "2026-03-01T00:00:00"
                 },
                 fetch_status: :not_fetched
               },
               %NormalizedSearchHit{
                 provider: :brave,
                 query: ^query,
                 rank: 2,
                 title: "Forecast scoring in markets",
                 url: "https://example.com/scoring",
                 snippet: "Scoring-rule implications for traders",
                 raw_payload: %{
                   "type" => "search_result",
                   "title" => "Forecast scoring in markets",
                   "url" => "https://example.com/scoring",
                   "description" => "Scoring-rule implications for traders"
                 },
                 fetch_status: :not_fetched
               }
             ]
           } = result
  end

  test "clamps BRAVE count to the documented provider max" do
    Req.Test.expect(request_test_name(), fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      assert conn.method == "GET"
      assert conn.request_path == "/res/v1/web/search"
      assert %{"count" => "20", "q" => "prediction market calibration"} = conn.query_params

      Req.Test.json(conn, %{
        "query" => %{"original" => "prediction market calibration"},
        "web" => %{
          "results" => [
            %{
              "title" => "Calibration in prediction markets",
              "url" => "https://example.com/calibration"
            }
          ]
        }
      })
    end)

    assert {:ok, %ProviderResult{} = result} =
             BraveSearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 25),
               api_key: "test-brave-key",
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

  test "returns an explicit provider error for non-200 BRAVE responses" do
    Req.Test.expect(request_test_name(), fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(429, Jason.encode!(%{"message" => "Rate limit exceeded"}))
    end)

    assert {:error, %ProviderError{} = error} =
             BraveSearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 1),
               api_key: "test-brave-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderError{
             provider: :brave,
             request_kind: :search,
             reason: :rate_limited,
             status: 429,
             retryable: true,
             message: "Rate limit exceeded",
             raw_payload: %{"message" => "Rate limit exceeded"}
           } = error
  end

  test "returns an explicit provider error for malformed successful payloads" do
    Req.Test.expect(request_test_name(), fn conn ->
      Req.Test.json(conn, %{
        "query" => %{"original" => "prediction market calibration"},
        "web" => %{
          "results" => [
            %{
              "title" => "Missing URL"
            }
          ]
        }
      })
    end)

    assert {:error, %ProviderError{} = error} =
             BraveSearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 1),
               api_key: "test-brave-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderError{
             provider: :brave,
             request_kind: :search,
             reason: :malformed_payload,
             status: nil,
             retryable: false,
             raw_payload: %{
               "query" => %{"original" => "prediction market calibration"},
               "web" => %{"results" => [%{"title" => "Missing URL"}]}
             }
           } = error

    assert error.message =~ "missing title or url"
  end

  defp search_request(query, max_results) do
    %SearchRequest{provider: :brave, query: query, max_results: max_results}
  end

  defp req do
    ProviderConfig.new_request(plug: {Req.Test, request_test_name()})
  end

  defp request_test_name do
    __MODULE__.BRAVE
  end

  defp ensure_req_test_ownership_started do
    case Process.whereis(Req.Test.Ownership) do
      nil -> start_supervised!({Req.Test.Ownership, name: Req.Test.Ownership})
      _pid -> :ok
    end
  end
end
