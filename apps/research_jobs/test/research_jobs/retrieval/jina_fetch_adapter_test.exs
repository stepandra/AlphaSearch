defmodule ResearchJobs.Retrieval.JinaFetchAdapterTest do
  use ExUnit.Case, async: false

  alias ResearchCore.Branch.SearchQuery

  alias ResearchCore.Retrieval.{
    FetchRequest,
    FetchResult,
    FetchedDocument,
    NormalizedSearchHit,
    ProviderError
  }

  alias ResearchJobs.Retrieval.{JinaFetchAdapter, ProviderConfig}

  setup do
    ensure_req_test_ownership_started()
    :ok
  end

  test "builds a basic Jina reader request and normalizes a fetched document" do
    request = fetch_request("https://example.com/calibration")

    Req.Test.expect(request_test_name(), fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/http://example.com/calibration"
      assert ["application/json"] == Plug.Conn.get_req_header(conn, "accept")
      assert ["Bearer test-jina-key"] == Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        "code" => 200,
        "status" => 20000,
        "data" => %{
          "url" => "https://example.com/calibration",
          "title" => "Calibration in prediction markets",
          "content" => "Useful cleaned text",
          "publishedTime" => "Tue, 24 Mar 2026 22:07:32 GMT"
        },
        "meta" => %{"usage" => %{"tokens" => 128}}
      })
    end)

    assert {:ok, %FetchResult{} = result} =
             JinaFetchAdapter.fetch(
               request,
               api_key: "test-jina-key",
               req: req()
             )

    Req.Test.verify!()

    assert %FetchResult{
             request: ^request,
             status: :ok,
             error: nil,
             document: %FetchedDocument{
               url: "https://example.com/calibration",
               title: "Calibration in prediction markets",
               content: "Useful cleaned text",
               content_format: :text,
               raw_payload: %{
                 "code" => 200,
                 "status" => 20000,
                 "data" => %{
                   "url" => "https://example.com/calibration",
                   "title" => "Calibration in prediction markets",
                   "content" => "Useful cleaned text",
                   "publishedTime" => "Tue, 24 Mar 2026 22:07:32 GMT"
                 }
               },
               fetched_at: ~U[2026-03-24 22:07:32Z]
             }
           } = result
  end

  test "returns an explicit provider error for non-200 Jina responses" do
    Req.Test.expect(request_test_name(), fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(429, Jason.encode!(%{"detail" => "Too Many Requests"}))
    end)

    assert {:error, %ProviderError{} = error} =
             JinaFetchAdapter.fetch(
               fetch_request("https://example.com/calibration"),
               api_key: "test-jina-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderError{
             provider: :jina,
             request_kind: :fetch,
             reason: :rate_limited,
             status: 429,
             retryable: true,
             message: "Too Many Requests",
             raw_payload: %{"detail" => "Too Many Requests"}
           } = error
  end

  test "returns an explicit invalid-url provider error before executing the request" do
    assert {:error, %ProviderError{} = error} =
             JinaFetchAdapter.fetch(
               fetch_request("mailto:calibration@example.com"),
               api_key: "test-jina-key",
               req: req()
             )

    assert %ProviderError{
             provider: :jina,
             request_kind: :fetch,
             reason: :invalid_url,
             retryable: false,
             message: "Jina Reader requires an absolute http(s) URL",
             raw_payload: "mailto:calibration@example.com"
           } = error
  end

  test "returns an explicit timeout provider error for transport timeouts" do
    Req.Test.expect(request_test_name(), fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error, %ProviderError{} = error} =
             JinaFetchAdapter.fetch(
               fetch_request("https://example.com/slow-calibration"),
               api_key: "test-jina-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderError{
             provider: :jina,
             request_kind: :fetch,
             reason: :timeout,
             retryable: true
           } = error

    assert error.message =~ "timeout"
  end

  test "returns an explicit provider error for malformed successful payloads" do
    Req.Test.expect(request_test_name(), fn conn ->
      Req.Test.json(conn, %{
        "code" => 200,
        "status" => 20000,
        "data" => %{
          "url" => "https://example.com/calibration",
          "title" => "Calibration in prediction markets"
        }
      })
    end)

    assert {:error, %ProviderError{} = error} =
             JinaFetchAdapter.fetch(
               fetch_request("https://example.com/calibration"),
               api_key: "test-jina-key",
               req: req()
             )

    Req.Test.verify!()

    assert %ProviderError{
             provider: :jina,
             request_kind: :fetch,
             reason: :malformed_payload,
             status: nil,
             retryable: false,
             raw_payload: %{
               "code" => 200,
               "status" => 20000,
               "data" => %{
                 "url" => "https://example.com/calibration",
                 "title" => "Calibration in prediction markets"
               }
             }
           } = error

    assert error.message =~ "missing content"
  end

  defp fetch_request(url) do
    %FetchRequest{
      provider: :jina,
      url: url,
      source_hit: %NormalizedSearchHit{
        provider: :serper,
        query: %SearchQuery{text: "prediction market calibration"},
        rank: 1,
        title: "Calibration in prediction markets",
        url: url,
        snippet: "Empirical study of forecast calibration",
        raw_payload: %{"link" => url},
        fetch_status: :not_fetched
      }
    }
  end

  defp req do
    ProviderConfig.new_request(plug: {Req.Test, request_test_name()})
  end

  defp request_test_name do
    __MODULE__.JINA
  end

  defp ensure_req_test_ownership_started do
    case Process.whereis(Req.Test.Ownership) do
      nil -> start_supervised!({Req.Test.Ownership, name: Req.Test.Ownership})
      _pid -> :ok
    end
  end
end
