defmodule ResearchJobs.Retrieval.ExaSearchAdapter do
  @moduledoc """
  Explicit EXA basic-search adapter.

  The adapter issues one straightforward Exa `/search` request via `Req`,
  normalizes `results` into the shared retrieval structs, and preserves a
  bounded raw payload subset for downstream provenance and debugging.
  """

  @behaviour ResearchJobs.Retrieval.SearchAdapter

  alias ResearchCore.Retrieval.{NormalizedSearchHit, ProviderError, ProviderResult, SearchRequest}
  alias ResearchJobs.Retrieval.ProviderConfig

  @max_results 100
  @search_type "fast"
  @raw_payload_keys ["requestId", "results", "searchType", "costDollars"]

  @impl true
  def search(request, opts \\ [])

  @spec search(SearchRequest.t(), keyword()) ::
          {:ok, ProviderResult.t()} | {:error, ProviderError.t()}
  def search(%SearchRequest{provider: :exa} = request, opts) do
    provider_config = ProviderConfig.provider!(:exa)

    with {:ok, api_key} <- fetch_api_key(provider_config, opts),
         {:ok, response} <- execute_request(request, provider_config.endpoint, api_key, opts) do
      normalize_response(request, response)
    end
  end

  def search(%SearchRequest{provider: provider}, _opts) do
    {:error,
     %ProviderError{
       provider: :exa,
       request_kind: :search,
       reason: :unsupported_request,
       message: "EXA adapter expected a :exa request, got #{inspect(provider)}"
     }}
  end

  defp fetch_api_key(provider_config, opts) do
    case Keyword.get(opts, :api_key) || System.get_env(provider_config.api_key_env) do
      api_key when is_binary(api_key) and api_key != "" ->
        {:ok, api_key}

      _missing ->
        {:error,
         %ProviderError{
           provider: :exa,
           request_kind: :search,
           reason: :missing_api_key,
           message: "EXA API key is not configured"
         }}
    end
  end

  defp execute_request(request, endpoint, api_key, opts) do
    req = Keyword.get(opts, :req, ProviderConfig.new_request())

    request_options = [
      method: :post,
      url: endpoint,
      retry: false,
      headers: [{"x-api-key", api_key}],
      json: search_payload(request)
    ]

    case Req.request(req, request_options) do
      {:ok, response} ->
        {:ok, response}

      {:error, exception} ->
        {:error,
         %ProviderError{
           provider: :exa,
           request_kind: :search,
           reason: :transport_error,
           message: Exception.message(exception),
           retryable: true,
           raw_payload: exception
         }}
    end
  end

  defp normalize_response(_request, %Req.Response{status: status, body: body})
       when status >= 400 do
    reason =
      case status do
        429 -> :rate_limited
        _ -> :http_error
      end

    {:error,
     %ProviderError{
       provider: :exa,
       request_kind: :search,
       reason: reason,
       status: status,
       retryable: reason == :rate_limited or status >= 500,
       message: response_message(body, "EXA search request failed with status #{status}"),
       raw_payload: body
     }}
  end

  defp normalize_response(request, %Req.Response{body: body}) do
    with {:ok, results} <- results(body),
         {:ok, normalized_hits} <- normalize_hits(results, request, raw_payload_subset(body)) do
      {:ok,
       %ProviderResult{
         provider: :exa,
         request: request,
         hits: normalized_hits,
         raw_payload: raw_payload_subset(body)
       }}
    end
  end

  defp results(%{"results" => results}) when is_list(results), do: {:ok, results}

  defp results(body) do
    {:error,
     %ProviderError{
       provider: :exa,
       request_kind: :search,
       reason: :malformed_payload,
       message: "EXA response is missing a results list",
       raw_payload: raw_payload_subset(body)
     }}
  end

  defp normalize_hits(results, request, raw_payload) do
    results
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {result, fallback_rank}, {:ok, hits} ->
      case normalize_hit(result, request, fallback_rank) do
        {:ok, hit} ->
          {:cont, {:ok, [hit | hits]}}

        {:error, message} ->
          {:halt,
           {:error,
            %ProviderError{
              provider: :exa,
              request_kind: :search,
              reason: :malformed_payload,
              message: message,
              raw_payload: raw_payload
            }}}
      end
    end)
    |> case do
      {:ok, hits} -> {:ok, Enum.reverse(hits)}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_hit(%{"title" => title, "url" => url} = result, request, fallback_rank)
       when is_binary(title) and is_binary(url) and title != "" and url != "" do
    {:ok,
     %NormalizedSearchHit{
       provider: :exa,
       query: request.query,
       rank: fallback_rank,
       title: title,
       url: url,
       snippet: optional_string(result["text"] || result["summary"]),
       raw_payload: result
     }}
  end

  defp normalize_hit(_result, _request, fallback_rank) do
    {:error, "EXA result at index #{fallback_rank} is missing title or url"}
  end

  defp search_payload(%SearchRequest{query: query, max_results: max_results}) do
    payload = %{"query" => query.text, "type" => @search_type}

    if is_integer(max_results) and max_results > 0 do
      Map.put(payload, "numResults", min(max_results, @max_results))
    else
      payload
    end
  end

  defp raw_payload_subset(body) when is_map(body), do: Map.take(body, @raw_payload_keys)
  defp raw_payload_subset(body), do: body

  defp response_message(%{"message" => message}, _fallback) when is_binary(message), do: message
  defp response_message(%{"detail" => message}, _fallback) when is_binary(message), do: message
  defp response_message(%{"error" => message}, _fallback) when is_binary(message), do: message
  defp response_message(message, _fallback) when is_binary(message) and message != "", do: message
  defp response_message(_body, fallback), do: fallback

  defp optional_string(value) when is_binary(value) and value != "", do: value
  defp optional_string(_value), do: nil
end
