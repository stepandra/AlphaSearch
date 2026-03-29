defmodule ResearchJobs.Retrieval.SerperSearchAdapter do
  @moduledoc """
  Explicit SERPER basic-search adapter.

  The adapter issues a single straightforward search request via `Req`, maps the
  `organic` response list into the shared retrieval structs, and preserves
  provider provenance plus a small raw payload subset for audit.
  """

  @behaviour ResearchJobs.Retrieval.SearchAdapter

  alias ResearchCore.Retrieval.{NormalizedSearchHit, ProviderError, ProviderResult, SearchRequest}
  alias ResearchJobs.Retrieval.ProviderConfig

  @raw_payload_keys ["organic", "searchParameters"]

  @impl true
  def search(request, opts \\ [])

  @spec search(SearchRequest.t(), keyword()) ::
          {:ok, ProviderResult.t()} | {:error, ProviderError.t()}
  def search(%SearchRequest{provider: :serper} = request, opts) do
    provider_config = ProviderConfig.provider!(:serper)

    with {:ok, api_key} <- fetch_api_key(provider_config, opts),
         {:ok, response} <- execute_request(request, provider_config.endpoint, api_key, opts) do
      normalize_response(request, response)
    end
  end

  def search(%SearchRequest{provider: provider}, _opts) do
    {:error,
     %ProviderError{
       provider: :serper,
       request_kind: :search,
       reason: :unsupported_request,
       message: "SERPER adapter expected a :serper request, got #{inspect(provider)}"
     }}
  end

  defp fetch_api_key(provider_config, opts) do
    case Keyword.get(opts, :api_key) || System.get_env(provider_config.api_key_env) do
      api_key when is_binary(api_key) and api_key != "" ->
        {:ok, api_key}

      _missing ->
        {:error,
         %ProviderError{
           provider: :serper,
           request_kind: :search,
           reason: :missing_api_key,
           message: "SERPER API key is not configured"
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
           provider: :serper,
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
       provider: :serper,
       request_kind: :search,
       reason: reason,
       status: status,
       retryable: reason == :rate_limited or status >= 500,
       message: response_message(body, "SERPER search request failed with status #{status}"),
       raw_payload: body
     }}
  end

  defp normalize_response(request, %Req.Response{body: body}) do
    with {:ok, organic_hits} <- organic_hits(body),
         {:ok, normalized_hits} <- normalize_hits(organic_hits, request, raw_payload_subset(body)) do
      {:ok,
       %ProviderResult{
         provider: :serper,
         request: request,
         hits: normalized_hits,
         raw_payload: raw_payload_subset(body)
       }}
    end
  end

  defp organic_hits(%{"organic" => organic_hits}) when is_list(organic_hits),
    do: {:ok, organic_hits}

  defp organic_hits(body) do
    {:error,
     %ProviderError{
       provider: :serper,
       request_kind: :search,
       reason: :malformed_payload,
       message: "SERPER response is missing an organic results list",
       raw_payload: raw_payload_subset(body)
     }}
  end

  defp normalize_hits(organic_hits, request, raw_payload) do
    organic_hits
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {organic_hit, fallback_rank}, {:ok, hits} ->
      case normalize_hit(organic_hit, request, fallback_rank) do
        {:ok, hit} ->
          {:cont, {:ok, [hit | hits]}}

        {:error, message} ->
          {:halt,
           {:error,
            %ProviderError{
              provider: :serper,
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

  defp normalize_hit(%{"title" => title, "link" => url} = organic_hit, request, fallback_rank)
       when is_binary(title) and is_binary(url) and title != "" and url != "" do
    {:ok,
     %NormalizedSearchHit{
       provider: :serper,
       query: request.query,
       rank: rank(organic_hit["position"], fallback_rank),
       title: title,
       url: url,
       snippet: optional_string(organic_hit["snippet"]),
       raw_payload: organic_hit
     }}
  end

  defp normalize_hit(_organic_hit, _request, fallback_rank) do
    {:error, "SERPER organic result at index #{fallback_rank} is missing title or link"}
  end

  defp search_payload(%SearchRequest{query: query, max_results: max_results}) do
    payload = %{"q" => query.text}

    if is_integer(max_results) and max_results > 0 do
      Map.put(payload, "num", max_results)
    else
      payload
    end
  end

  defp raw_payload_subset(body) when is_map(body), do: Map.take(body, @raw_payload_keys)
  defp raw_payload_subset(body), do: body

  defp response_message(%{"message" => message}, _fallback) when is_binary(message), do: message
  defp response_message(%{"error" => message}, _fallback) when is_binary(message), do: message
  defp response_message(_body, fallback), do: fallback

  defp optional_string(value) when is_binary(value) and value != "", do: value
  defp optional_string(_value), do: nil

  defp rank(value, _fallback_rank) when is_integer(value) and value > 0, do: value

  defp rank(value, fallback_rank) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> fallback_rank
    end
  end

  defp rank(_value, fallback_rank), do: fallback_rank
end
