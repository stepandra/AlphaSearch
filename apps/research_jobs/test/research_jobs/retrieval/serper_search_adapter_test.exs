defmodule ResearchJobs.Retrieval.SerperSearchAdapterTest do
  use ExUnit.Case, async: false

  alias ResearchCore.Branch.SearchQuery

  alias ResearchCore.Retrieval.{
    NormalizedSearchHit,
    ProviderError,
    ProviderResult,
    SearchRequest
  }

  alias ResearchJobs.Retrieval.{ProviderConfig, SerperSearchAdapter}

  setup do
    ensure_req_test_ownership_started()
    :ok
  end

  test "builds a basic SERPER request and normalizes organic hits" do
    query = %SearchQuery{text: "prediction market calibration"}
    request = search_request(query, 2)

    Req.Test.expect(request_test_name(), fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/search"
      assert ["test-serper-key"] == Plug.Conn.get_req_header(conn, "x-api-key")

      assert %{"num" => 2, "q" => "prediction market calibration"} =
               Req.Test.raw_body(conn)
               |> Jason.decode!()

      Req.Test.json(conn, %{
        "searchParameters" => %{"q" => "prediction market calibration"},
        "organic" => [
          %{
            "position" => 1,
            "title" => "Calibration in prediction markets",
            "link" => "https://example.com/calibration",
            "snippet" => "Empirical study of forecast calibration",
            "date" => "2026-03-01"
          },
          %{
            "title" => "Forecast scoring in markets",
            "link" => "https://example.com/scoring",
            "snippet" => "Scoring-rule implications for traders"
          }
        ],
        "credits" => 1
      })
    end)

    assert {:ok, %ProviderResult{} = result} =
             SerperSearchAdapter.search(
               request,
               api_key: "test-serper-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderResult{
             provider: :serper,
             request: ^request,
             raw_payload: %{
               "organic" => [
                 %{
                   "position" => 1,
                   "title" => "Calibration in prediction markets",
                   "link" => "https://example.com/calibration",
                   "snippet" => "Empirical study of forecast calibration",
                   "date" => "2026-03-01"
                 },
                 %{
                   "title" => "Forecast scoring in markets",
                   "link" => "https://example.com/scoring",
                   "snippet" => "Scoring-rule implications for traders"
                 }
               ],
               "searchParameters" => %{"q" => "prediction market calibration"}
             },
             hits: [
               %NormalizedSearchHit{
                 provider: :serper,
                 query: ^query,
                 rank: 1,
                 title: "Calibration in prediction markets",
                 url: "https://example.com/calibration",
                 snippet: "Empirical study of forecast calibration",
                 raw_payload: %{
                   "position" => 1,
                   "title" => "Calibration in prediction markets",
                   "link" => "https://example.com/calibration",
                   "snippet" => "Empirical study of forecast calibration",
                   "date" => "2026-03-01"
                 },
                 fetch_status: :not_fetched
               },
               %NormalizedSearchHit{
                 provider: :serper,
                 query: ^query,
                 rank: 2,
                 title: "Forecast scoring in markets",
                 url: "https://example.com/scoring",
                 snippet: "Scoring-rule implications for traders",
                 raw_payload: %{
                   "title" => "Forecast scoring in markets",
                   "link" => "https://example.com/scoring",
                   "snippet" => "Scoring-rule implications for traders"
                 },
                 fetch_status: :not_fetched
               }
             ]
           } = result
  end

  test "returns an explicit provider error for non-200 SERPER responses" do
    Req.Test.expect(request_test_name(), fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(429, Jason.encode!(%{"message" => "Too Many Requests"}))
    end)

    assert {:error, %ProviderError{} = error} =
             SerperSearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 1),
               api_key: "test-serper-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderError{
             provider: :serper,
             request_kind: :search,
             reason: :rate_limited,
             status: 429,
             retryable: true,
             message: "Too Many Requests",
             raw_payload: %{"message" => "Too Many Requests"}
           } = error
  end

  test "returns an explicit provider error for malformed successful payloads" do
    Req.Test.expect(request_test_name(), fn conn ->
      Req.Test.json(conn, %{
        "searchParameters" => %{"q" => "prediction market calibration"},
        "organic" => [%{"title" => "Missing link"}]
      })
    end)

    assert {:error, %ProviderError{} = error} =
             SerperSearchAdapter.search(
               search_request(%SearchQuery{text: "prediction market calibration"}, 1),
               api_key: "test-serper-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderError{
             provider: :serper,
             request_kind: :search,
             reason: :malformed_payload,
             status: nil,
             retryable: false,
             raw_payload: %{
               "searchParameters" => %{"q" => "prediction market calibration"},
               "organic" => [%{"title" => "Missing link"}]
             }
           } = error

    assert error.message =~ "missing title or link"
  end

  defp search_request(query, max_results) do
    %SearchRequest{provider: :serper, query: query, max_results: max_results}
  end

  defp req do
    ProviderConfig.new_request(plug: {Req.Test, request_test_name()})
  end

  defp request_test_name do
    __MODULE__.SERPER
  end

  defp ensure_req_test_ownership_started do
    case Process.whereis(Req.Test.Ownership) do
      nil -> start_supervised!({Req.Test.Ownership, name: Req.Test.Ownership})
      _pid -> :ok
    end
  end
end
