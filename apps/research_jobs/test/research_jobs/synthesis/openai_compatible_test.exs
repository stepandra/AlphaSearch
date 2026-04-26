defmodule ResearchJobs.Synthesis.Providers.OpenAICompatibleTest do
  use ExUnit.Case, async: false

  alias ResearchJobs.Synthesis.{ProviderError, ProviderResponse}
  alias ResearchJobs.Synthesis.Providers.OpenAICompatible
  alias ResearchCore.Canonical

  setup do
    ensure_req_test_ownership_started()
    :ok
  end

  test "builds a chat completions request and normalizes markdown content" do
    Req.Test.expect(request_test_name(), fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/chat/completions"
      assert ["Bearer synth-key"] == Plug.Conn.get_req_header(conn, "authorization")

      assert %{
               "model" => "test-synthesis-model",
               "temperature" => 0.15,
               "messages" => [
                 %{"role" => "system"},
                 %{"role" => "user", "content" => "prompt-body"}
               ]
             } =
               Req.Test.raw_body(conn)
               |> Jason.decode!()

      Req.Test.json(conn, %{
        "id" => "chatcmpl_synth_123",
        "model" => "test-synthesis-model",
        "choices" => [
          %{
            "finish_reason" => "stop",
            "message" => %{"content" => "## Executive Summary\nNotebook smoke output."}
          }
        ],
        "usage" => %{"total_tokens" => 321}
      })
    end)

    assert {:ok, %ProviderResponse{} = response} =
             OpenAICompatible.synthesize(
               %{prompt: "prompt-body"},
               api_key: "synth-key",
               model: "test-synthesis-model",
               temperature: 0.15,
               req: req()
             )

    Req.Test.verify!()

    assert response.provider == "openai_compatible"
    assert response.model == "test-synthesis-model"
    assert response.response_id == "chatcmpl_synth_123"
    assert response.content == "## Executive Summary\nNotebook smoke output."
    assert response.metadata.finish_reason == "stop"
    assert response.metadata.usage == %{"total_tokens" => 321}
    assert response.request_hash == Canonical.hash(%{prompt: "prompt-body"})

    assert response.response_hash ==
             Canonical.hash("## Executive Summary\nNotebook smoke output.")
  end

  test "falls back to canonical JSON request content when prompt text is absent" do
    request_spec = %{phase: :synthesis, payload: %{b: 2, a: 1}}

    Req.Test.expect(request_test_name(), fn conn ->
      assert %{
               "messages" => [
                 %{"role" => "system"},
                 %{"role" => "user", "content" => content}
               ]
             } =
               Req.Test.raw_body(conn)
               |> Jason.decode!()

      assert Jason.decode!(content) == Jason.decode!(Canonical.encode!(request_spec))

      Req.Test.json(conn, %{
        "id" => "chatcmpl_synth_456",
        "model" => "test-synthesis-model",
        "choices" => [
          %{"finish_reason" => "stop", "message" => %{"content" => "## Executive Summary\nOK"}}
        ]
      })
    end)

    assert {:ok, %ProviderResponse{} = response} =
             OpenAICompatible.synthesize(
               request_spec,
               api_key: "synth-key",
               model: "test-synthesis-model",
               req: req()
             )

    Req.Test.verify!()

    assert response.request_hash == Canonical.hash(request_spec)
  end

  test "returns explicit provider errors for failed HTTP responses" do
    Req.Test.expect(request_test_name(), fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => %{"message" => "provider failure"}}))
    end)

    assert {:error, %ProviderError{} = error} =
             OpenAICompatible.synthesize(
               %{prompt: "prompt-body"},
               api_key: "synth-key",
               model: "test-synthesis-model",
               req: req()
             )

    Req.Test.verify!()

    assert error.provider == "openai_compatible"
    assert error.reason == :http_error
    assert error.retryable?
    assert error.message == "provider failure"
    assert error.details.status == 500
  end

  defp req do
    Req.new(plug: {Req.Test, request_test_name()})
  end

  defp request_test_name do
    __MODULE__.OPENAI
  end

  defp ensure_req_test_ownership_started do
    case Process.whereis(Req.Test.Ownership) do
      nil -> start_supervised!({Req.Test.Ownership, name: Req.Test.Ownership})
      _pid -> :ok
    end
  end
end
