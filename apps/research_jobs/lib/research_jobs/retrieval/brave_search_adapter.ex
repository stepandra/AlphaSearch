defmodule ResearchJobs.Retrieval.BraveSearchAdapter do
  @moduledoc """
  Explicit BRAVE basic-search adapter.

  The adapter issues one straightforward Brave web search request via `Req`,
  normalizes `web.results` into the shared retrieval structs, and preserves a
  bounded raw payload subset for downstream provenance and debugging.
  """

  @behaviour ResearchJobs.Retrieval.SearchAdapter

  alias ResearchCore.Retrieval.{NormalizedSearchHit, ProviderError, ProviderResult, SearchRequest}
  alias ResearchJobs.Retrieval.ProviderConfig

  @max_count 20
  @raw_payload_keys ["query", "web"]
  @web_payload_keys ["results"]

  @impl true
  def search(request, opts \\ [])

  @spec search(SearchRequest.t(), keyword()) ::
          {:ok, ProviderResult.t()} | {:error, ProviderError.t()}
  def search(%SearchRequest{provider: :brave} = request, opts) do
    provider_config = ProviderConfig.provider!(:brave)

    with {:ok, api_key} <- fetch_api_key(provider_config, opts),
         {:ok, response} <- execute_request(request, provider_config.endpoint, api_key, opts) do
      normalize_response(request, response)
    end
  end

  def search(%SearchRequest{provider: provider}, _opts) do
    {:error,
     %ProviderError{
       provider: :brave,
       request_kind: :search,
       reason: :unsupported_request,
       message: "BRAVE adapter expected a :brave request, got #{inspect(provider)}"
     }}
  end

  defp fetch_api_key(provider_config, opts) do
    case Keyword.get(opts, :api_key) || System.get_env(provider_config.api_key_env) do
      api_key when is_binary(api_key) and api_key != "" ->
        {:ok, api_key}

      _missing ->
        {:error,
         %ProviderError{
           provider: :brave,
           request_kind: :search,
           reason: :missing_api_key,
           message: "BRAVE API key is not configured"
         }}
    end
  end

  defp execute_request(request, endpoint, api_key, opts) do
    req = Keyword.get(opts, :req, ProviderConfig.new_request())

    request_options = [
      method: :get,
      url: endpoint,
      retry: false,
      headers: [{"x-subscription-token", api_key}],
      params: search_params(request)
    ]

    case Req.request(req, request_options) do
      {:ok, response} ->
        {:ok, response}

      {:error, exception} ->
        {:error,
         %ProviderError{
           provider: :brave,
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
       provider: :brave,
       request_kind: :search,
       reason: reason,
       status: status,
       retryable: reason == :rate_limited or status >= 500,
       message: response_message(body, "BRAVE search request failed with status #{status}"),
       raw_payload: body
     }}
  end

  defp normalize_response(request, %Req.Response{body: body}) do
    with {:ok, web_results} <- web_results(body),
         {:ok, normalized_hits} <- normalize_hits(web_results, request, raw_payload_subset(body)) do
      {:ok,
       %ProviderResult{
         provider: :brave,
         request: request,
         hits: normalized_hits,
         raw_payload: raw_payload_subset(body)
       }}
    end
  end

  defp web_results(%{"web" => %{"results" => results}}) when is_list(results), do: {:ok, results}

  defp web_results(body) do
    {:error,
     %ProviderError{
       provider: :brave,
       request_kind: :search,
       reason: :malformed_payload,
       message: "BRAVE response is missing a web results list",
       raw_payload: raw_payload_subset(body)
     }}
  end

  defp normalize_hits(web_results, request, raw_payload) do
    web_results
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {web_hit, fallback_rank}, {:ok, hits} ->
      case normalize_hit(web_hit, request, fallback_rank) do
        {:ok, hit} ->
          {:cont, {:ok, [hit | hits]}}

        {:error, message} ->
          {:halt,
           {:error,
            %ProviderError{
              provider: :brave,
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

  defp normalize_hit(%{"title" => title, "url" => url} = web_hit, request, fallback_rank)
       when is_binary(title) and is_binary(url) and title != "" and url != "" do
    {:ok,
     %NormalizedSearchHit{
       provider: :brave,
       query: request.query,
       rank: fallback_rank,
       title: title,
       url: url,
       snippet: optional_string(web_hit["description"]),
       raw_payload: web_hit
     }}
  end

  defp normalize_hit(_web_hit, _request, fallback_rank) do
    {:error, "BRAVE web result at index #{fallback_rank} is missing title or url"}
  end

  defp search_params(%SearchRequest{query: query, max_results: max_results}) do
    params = %{"q" => query.text}

    if is_integer(max_results) and max_results > 0 do
      Map.put(params, "count", min(max_results, @max_count))
    else
      params
    end
  end

  defp raw_payload_subset(%{"web" => web} = body) when is_map(web) do
    body
    |> Map.take(@raw_payload_keys)
    |> Map.put("web", Map.take(web, @web_payload_keys))
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
