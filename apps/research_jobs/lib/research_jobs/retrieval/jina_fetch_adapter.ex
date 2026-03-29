defmodule ResearchJobs.Retrieval.JinaFetchAdapter do
  @moduledoc """
  Explicit Jina Reader fetch adapter.

  The adapter performs one basic Reader request via `Req`, prefers JSON mode for
  a small normalized payload, and maps the response into the shared fetch
  structs without adding pipeline behavior or provider-specific post-processing.
  """

  @behaviour ResearchJobs.Retrieval.FetchAdapter

  alias ResearchCore.Retrieval.{FetchRequest, FetchResult, FetchedDocument, ProviderError}
  alias ResearchJobs.Retrieval.ProviderConfig

  @document_payload_keys ["url", "title", "content", "publishedTime", "timestamp"]
  @envelope_payload_keys ["code", "status", "data"]

  @impl true
  def fetch(request, opts \\ [])

  @spec fetch(FetchRequest.t(), keyword()) ::
          {:ok, FetchResult.t()} | {:error, ProviderError.t()}
  def fetch(%FetchRequest{provider: :jina} = request, opts) do
    provider_config = ProviderConfig.provider!(:jina)

    with {:ok, request_url} <- request_url(request.url, provider_config.endpoint),
         {:ok, response} <- execute_request(request_url, provider_config, opts) do
      normalize_response(request, response)
    end
  end

  def fetch(%FetchRequest{provider: provider}, _opts) do
    {:error,
     %ProviderError{
       provider: :jina,
       request_kind: :fetch,
       reason: :unsupported_request,
       message: "Jina adapter expected a :jina request, got #{inspect(provider)}"
     }}
  end

  defp execute_request(request_url, provider_config, opts) do
    req = Keyword.get(opts, :req, ProviderConfig.new_request())

    request_options = [
      method: :get,
      url: request_url,
      retry: false,
      headers: request_headers(provider_config, opts)
    ]

    case Req.request(req, request_options) do
      {:ok, response} ->
        {:ok, response}

      {:error, exception} ->
        {:error,
         %ProviderError{
           provider: :jina,
           request_kind: :fetch,
           reason: transport_error_reason(exception),
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
       provider: :jina,
       request_kind: :fetch,
       reason: reason,
       status: status,
       retryable: reason == :rate_limited or status >= 500,
       message: response_message(body, "Jina Reader request failed with status #{status}"),
       raw_payload: body
     }}
  end

  defp normalize_response(request, %Req.Response{body: body}) do
    case normalize_document(request, body) do
      {:ok, document} ->
        {:ok,
         %FetchResult{
           request: request,
           status: :ok,
           document: document
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  defp normalize_document(%FetchRequest{url: request_url}, body)
       when is_binary(body) and body != "" do
    {:ok,
     %FetchedDocument{
       url: request_url,
       title: nil,
       content: body,
       content_format: :text,
       raw_payload: body
     }}
  end

  defp normalize_document(%FetchRequest{url: request_url}, body) when is_map(body) do
    document_body = document_body(body)
    content = optional_string(document_body["content"])

    if content do
      {:ok,
       %FetchedDocument{
         url: optional_string(document_body["url"]) || request_url,
         title: optional_string(document_body["title"]),
         content: content,
         content_format: :text,
         raw_payload: raw_payload_subset(body),
         fetched_at: fetched_at(document_body)
       }}
    else
      {:error,
       %ProviderError{
         provider: :jina,
         request_kind: :fetch,
         reason: :malformed_payload,
         message: "Jina Reader response is missing content",
         raw_payload: raw_payload_subset(body)
       }}
    end
  end

  defp normalize_document(_request, body) do
    {:error,
     %ProviderError{
       provider: :jina,
       request_kind: :fetch,
       reason: :malformed_payload,
       message: "Jina Reader response could not be normalized",
       raw_payload: body
     }}
  end

  defp request_url(url, endpoint) when is_binary(url) and is_binary(endpoint) do
    parsed = URI.parse(url)

    cond do
      parsed.scheme not in ["http", "https"] or not is_binary(parsed.host) ->
        {:error,
         %ProviderError{
           provider: :jina,
           request_kind: :fetch,
           reason: :invalid_url,
           message: "Jina Reader requires an absolute http(s) URL",
           raw_payload: url
         }}

      scheme_placeholder_endpoint?(endpoint) ->
        {:ok, endpoint <> strip_scheme(url, parsed.scheme)}

      true ->
        {:ok, endpoint <> url}
    end
  end

  defp request_headers(provider_config, opts) do
    [{"accept", "application/json"}]
    |> maybe_put_authorization(provider_config, opts)
  end

  defp maybe_put_authorization(headers, provider_config, opts) do
    case api_key(provider_config, opts) do
      api_key when is_binary(api_key) and api_key != "" ->
        [{"authorization", "Bearer " <> api_key} | headers]

      _missing ->
        headers
    end
  end

  defp api_key(provider_config, opts) do
    Keyword.get(opts, :api_key) || System.get_env(provider_config.api_key_env)
  end

  defp scheme_placeholder_endpoint?(endpoint) do
    String.ends_with?(endpoint, "http://") or String.ends_with?(endpoint, "https://")
  end

  defp strip_scheme(url, scheme), do: String.replace_prefix(url, "#{scheme}://", "")

  defp document_body(%{"data" => data}) when is_map(data), do: data
  defp document_body(body) when is_map(body), do: body

  defp raw_payload_subset(%{"data" => data} = body) when is_map(data) do
    body
    |> Map.take(@envelope_payload_keys)
    |> Map.put("data", Map.take(data, @document_payload_keys))
  end

  defp raw_payload_subset(body) when is_map(body), do: Map.take(body, @document_payload_keys)
  defp raw_payload_subset(body), do: body

  defp fetched_at(body) when is_map(body) do
    (body["publishedTime"] || body["timestamp"])
    |> parse_datetime()
  end

  defp fetched_at(_body), do: nil

  defp parse_datetime(value) when is_binary(value) do
    parse_iso8601_datetime(value) || parse_rfc1123_datetime(value)
  end

  defp parse_datetime(_value), do: nil

  defp parse_iso8601_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _error -> nil
    end
  end

  defp parse_rfc1123_datetime(value) do
    case :httpd_util.convert_request_date(String.to_charlist(value)) do
      {{year, month, day}, {hour, minute, second}} ->
        with {:ok, date} <- Date.new(year, month, day),
             {:ok, time} <- Time.new(hour, minute, second),
             {:ok, naive_datetime} <- NaiveDateTime.new(date, time),
             {:ok, datetime} <- DateTime.from_naive(naive_datetime, "Etc/UTC") do
          datetime
        else
          _error -> nil
        end

      _other ->
        nil
    end
  rescue
    ArgumentError -> nil
  end

  defp transport_error_reason(%Req.TransportError{reason: :timeout}), do: :timeout
  defp transport_error_reason(_exception), do: :transport_error

  defp response_message(%{"message" => message}, _fallback) when is_binary(message), do: message
  defp response_message(%{"detail" => message}, _fallback) when is_binary(message), do: message
  defp response_message(%{"error" => message}, _fallback) when is_binary(message), do: message
  defp response_message(message, _fallback) when is_binary(message) and message != "", do: message
  defp response_message(_body, fallback), do: fallback

  defp optional_string(value) when is_binary(value) and value != "", do: value
  defp optional_string(_value), do: nil
end
