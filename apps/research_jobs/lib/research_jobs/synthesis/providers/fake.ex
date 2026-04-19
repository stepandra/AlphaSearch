defmodule ResearchJobs.Synthesis.Providers.Fake do
  @moduledoc """
  Fake synthesis provider for deterministic end-to-end tests.
  """

  @behaviour ResearchJobs.Synthesis.Provider

  alias ResearchJobs.Synthesis.{ProviderError, ProviderResponse}

  @impl true
  def synthesize(request_spec, opts) do
    cond do
      error = Keyword.get(opts, :error) ->
        {:error, error}

      content = Keyword.get(opts, :content) ->
        {:ok,
         %ProviderResponse{
           provider: Keyword.get(opts, :provider, "fake"),
           model: Keyword.get(opts, :model, "fake-model-v1"),
           content: content,
           request_id: Keyword.get(opts, :request_id, "fake-request-id"),
           response_id: Keyword.get(opts, :response_id, "fake-response-id"),
           request_hash: Keyword.get(opts, :request_hash, hash(request_spec.prompt)),
           response_hash: Keyword.get(opts, :response_hash, hash(content)),
           metadata: Keyword.get(opts, :metadata, %{})
         }}

      true ->
        {:error,
         %ProviderError{
           provider: "fake",
           reason: :missing_fake_content,
           message: "fake provider requires a :content option",
           details: %{}
         }}
    end
  end

  defp hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
  end
end
