defmodule ResearchJobs.Retrieval.TavilySearchAdapterTest do
  use ExUnit.Case, async: false

  alias ResearchCore.Branch.SearchQuery

  alias ResearchCore.Retrieval.{
    NormalizedSearchHit,
    ProviderError,
    ProviderResult,
    SearchRequest
  }

  alias ResearchJobs.Retrieval.{ProviderConfig, TavilySearchAdapter}

  setup do
    ensure_req_test_ownership_started()
    :ok
  end

  test "builds a basic TAVILY request and normalizes result hits" do
    query = %SearchQuery{text: "prediction market calibration"}
    request = search_request(query, 2)

    Req.Test.expect(request_test_name(), fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/search"
      assert ["Bearer test-tavily-key"] == Plug.Conn.get_req_header(conn, "authorization")

      assert %{
               "auto_parameters" => false,
               "include_answer" => false,
               "include_images" => false,
               "include_raw_content" => false,
               "max_results" => 2,
               "query" => "prediction market calibration",
               "search_depth" => "basic"
             } =
               conn
               |> Req.Test.raw_body()
               |> Jason.decode!()

      Req.Test.json(conn, %{
        "query" => "prediction market calibration",
        "results" => [
          %{
            "title" => "Calibration in prediction markets",
            "url" => "https://example.com/calibration",
            "content" => "Empirical study of forecast calibration",
            "score" => 0.81
          },
          %{
            "title" => "Forecast scoring in markets",
            "url" => "https://example.com/scoring",
            "content" => "Scoring-rule implications for traders"
          }
        ],
        "response_time" => "1.67",
        "auto_parameters" => %{"topic" => "general", "search_depth" => "basic"},
        "usage" => %{"credits" => 1},
        "request_id" => "req_123",
        "answer" => "ignored answer"
      })
    end)

    assert {:ok, %ProviderResult{} = result} =
             TavilySearchAdapter.search(
               request,
               api_key: "test-tavily-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderResult{
             provider: :tavily,
             request: ^request,
             raw_payload: %{
               "query" => "prediction market calibration",
               "results" => [
                 %{
                   "title" => "Calibration in prediction markets",
                   "url" => "https://example.com/calibration",
                   "content" => "Empirical study of forecast calibration",
                   "score" => 0.81
                 },
                 %{
                   "title" => "Forecast scoring in markets",
                   "url" => "https://example.com/scoring",
                   "content" => "Scoring-rule implications for traders"
                 }
               ],
               "response_time" => "1.67",
               "auto_parameters" => %{"topic" => "general", "search_depth" => "basic"},
               "usage" => %{"credits" => 1},
               "request_id" => "req_123"
             },
             hits: [
               %NormalizedSearchHit{
                 provider: :tavily,
                 query: ^query,
                 rank: 1,
                 title: "Calibration in prediction markets",
                 url: "https://example.com/calibration",
                 snippet: "Empirical study of forecast calibration",
                 raw_payload: %{
                   "title" => "Calibration in prediction markets",
                   "url" => "https://example.com/calibration",
                   "content" => "Empirical study of forecast calibration",
                   "score" => 0.81
                 },
                 fetch_status: :not_fetched
               },
               %NormalizedSearchHit{
                 provider: :tavily,
                 query: ^query,
                 rank: 2,
                 title: "Forecast scoring in markets",
                 url: "https://example.com/scoring",
                 snippet: "Scoring-rule implications for traders",
                 raw_payload: %{
                   "title" => "Forecast scoring in markets",
                   "url" => "https://example.com/scoring",
                   "content" => "Scoring-rule implications for traders"
                 },
                 fetch_status: :not_fetched
               }
             ]
           } = result
  end

  test "uses TAVILY_API_KEY when an explicit api_key opt is not provided" do
    previous_tavily_api_key = System.get_env("TAVILY_API_KEY")
    previous_legacy_tavily_api = System.get_env("TAVILY_API")

    on_exit(fn ->
      restore_env("TAVILY_API_KEY", previous_tavily_api_key)
      restore_env("TAVILY_API", previous_legacy_tavily_api)
    end)

    System.put_env("TAVILY_API_KEY", "env-tavily-key")
    System.delete_env("TAVILY_API")

    Req.Test.expect(request_test_name(), fn conn ->
      assert ["Bearer env-tavily-key"] == Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        "query" => "prediction market calibration",
        "results" => [
          %{
            "title" => "Calibration in prediction markets",
            "url" => "https://example.com/calibration"
          }
        ]
      })
    end)

    assert {:ok, %ProviderResult{} = result} =
             TavilySearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 1),
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

  test "clamps TAVILY max_results to the documented provider max" do
    Req.Test.expect(request_test_name(), fn conn ->
      assert %{
               "max_results" => 20,
               "query" => "prediction market calibration",
               "search_depth" => "basic"
             } =
               conn
               |> Req.Test.raw_body()
               |> Jason.decode!()

      Req.Test.json(conn, %{
        "query" => "prediction market calibration",
        "results" => [
          %{
            "title" => "Calibration in prediction markets",
            "url" => "https://example.com/calibration"
          }
        ]
      })
    end)

    assert {:ok, %ProviderResult{} = result} =
             TavilySearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 25),
               api_key: "test-tavily-key",
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

  test "returns an explicit provider error for non-200 TAVILY responses" do
    Req.Test.expect(request_test_name(), fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(429, Jason.encode!(%{"detail" => "Rate limit exceeded"}))
    end)

    assert {:error, %ProviderError{} = error} =
             TavilySearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 1),
               api_key: "test-tavily-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderError{
             provider: :tavily,
             request_kind: :search,
             reason: :rate_limited,
             status: 429,
             retryable: true,
             message: "Rate limit exceeded",
             raw_payload: %{"detail" => "Rate limit exceeded"}
           } = error
  end

  test "returns an explicit provider error for malformed successful payloads" do
    Req.Test.expect(request_test_name(), fn conn ->
      Req.Test.json(conn, %{
        "query" => "prediction market calibration",
        "results" => [%{"title" => "Missing URL"}],
        "request_id" => "req_123"
      })
    end)

    assert {:error, %ProviderError{} = error} =
             TavilySearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 1),
               api_key: "test-tavily-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderError{
             provider: :tavily,
             request_kind: :search,
             reason: :malformed_payload,
             status: nil,
             retryable: false,
             raw_payload: %{
               "query" => "prediction market calibration",
               "results" => [%{"title" => "Missing URL"}],
               "request_id" => "req_123"
             }
           } = error

    assert error.message =~ "missing title or url"
  end

  defp search_request(query, max_results) do
    %SearchRequest{provider: :tavily, query: query, max_results: max_results}
  end

  defp req do
    ProviderConfig.new_request(plug: {Req.Test, request_test_name()})
  end

  defp request_test_name do
    __MODULE__.TAVILY
  end

  defp ensure_req_test_ownership_started do
    case Process.whereis(Req.Test.Ownership) do
      nil -> start_supervised!({Req.Test.Ownership, name: Req.Test.Ownership})
      _pid -> :ok
    end
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)
end
