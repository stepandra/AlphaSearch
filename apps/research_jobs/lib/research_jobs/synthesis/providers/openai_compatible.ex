defmodule ResearchJobs.Synthesis.Providers.OpenAICompatible do
  @moduledoc """
  Live synthesis provider backed by an OpenAI-compatible chat completions API.
  """

  @behaviour ResearchJobs.Synthesis.Provider

  alias ResearchJobs.Synthesis.{ProviderConfig, ProviderError, ProviderResponse}
  alias ResearchCore.Canonical

  @provider_name "openai_compatible"

  @impl true
  def synthesize(request_spec, opts \\ []) when is_map(request_spec) do
    llm = ProviderConfig.llm()

    with {:ok, api_key} <- fetch_api_key(llm, opts),
         {:ok, model} <- fetch_model(llm, opts),
         {:ok, response} <- execute_request(request_spec, llm, api_key, model, opts) do
      normalize_response(response, request_spec, llm, model)
    end
  end

  defp fetch_api_key(llm, opts) do
    case Keyword.get(opts, :api_key) || System.get_env(llm.api_key_env) do
      api_key when is_binary(api_key) and api_key != "" ->
        {:ok, api_key}

      _missing ->
        {:error,
         %ProviderError{
           provider: @provider_name,
           reason: :not_configured,
           message: "no synthesis API key is configured",
           details: %{env: llm.api_key_env}
         }}
    end
  end

  defp fetch_model(llm, opts) do
    case Keyword.get(opts, :model) || System.get_env(llm.model_env) || llm.default_model do
      model when is_binary(model) and model != "" ->
        {:ok, model}

      _missing ->
        {:error,
         %ProviderError{
           provider: @provider_name,
           reason: :not_configured,
           message: "no synthesis model is configured",
           details: %{env: llm.model_env}
         }}
    end
  end

  defp execute_request(request_spec, llm, api_key, model, opts) do
    req = Keyword.get(opts, :req, Req.new(llm.http_options))

    request_options = [
      method: :post,
      url: endpoint(llm, opts),
      retry: false,
      headers: [
        {"authorization", "Bearer " <> api_key},
        {"content-type", "application/json"}
      ],
      json: request_payload(request_spec, model, llm, opts)
    ]

    case Req.request(req, request_options) do
      {:ok, %Req.Response{} = response} ->
        {:ok, response}

      {:error, exception} ->
        {:error,
         %ProviderError{
           provider: @provider_name,
           reason: :transport_error,
           message: Exception.message(exception),
           details: %{exception: inspect(exception)},
           retryable?: true
         }}
    end
  end

  defp normalize_response(%Req.Response{status: status, body: body}, _request_spec, _llm, _model)
       when status >= 400 do
    reason =
      case status do
        429 -> :rate_limited
        _ -> :http_error
      end

    {:error,
     %ProviderError{
       provider: @provider_name,
       reason: reason,
       message: response_message(body, "synthesis request failed with status #{status}"),
       details: %{status: status, body: body},
       retryable?: reason == :rate_limited or status >= 500
     }}
  end

  defp normalize_response(%Req.Response{body: body}, request_spec, llm, model) do
    with {:ok, content} <- extract_content(body) do
      {:ok,
       %ProviderResponse{
         provider: @provider_name,
         model: body_model(body) || model,
         content: content,
         request_id: nil,
         response_id: read_key(body, "id"),
         request_hash: hash(request_spec),
         response_hash: hash(content),
         metadata: %{
           api_url: env_or_default(llm.api_url_env, llm.api_url),
           finish_reason: choice_finish_reason(body),
           usage: read_key(body, "usage")
         }
       }}
    else
      {:error, reason} ->
        {:error,
         %ProviderError{
           provider: @provider_name,
           reason: :malformed_payload,
           message: reason,
           details: %{body: body}
         }}
    end
  end

  defp endpoint(llm, opts) do
    base_url = Keyword.get(opts, :api_url) || env_or_default(llm.api_url_env, llm.api_url)
    api_path = Keyword.get(opts, :api_path, llm.api_path)

    URI.merge(base_url, api_path) |> to_string()
  end

  defp request_payload(request_spec, model, llm, opts) do
    temperature = Keyword.get(opts, :temperature, llm.temperature)

    %{
      model: model,
      messages: [
        %{
          role: "system",
          content:
            "You synthesize finalized research snapshots into markdown reports. Follow the exact section order and citation rules. Return markdown only."
        },
        %{
          role: "user",
          content: request_spec[:prompt] || Canonical.encode!(request_spec)
        }
      ]
    }
    |> maybe_put(:temperature, temperature)
  end

  defp extract_content(body) do
    with [choice | _] <- read_key(body, "choices"),
         message when is_map(message) <- read_key(choice, "message"),
         {:ok, content} <- normalize_content(read_key(message, "content")),
         true <- content != "" do
      {:ok, content}
    else
      [] ->
        {:error, "synthesis response did not contain any choices"}

      false ->
        {:error, "synthesis response content was empty"}

      nil ->
        {:error, "synthesis response did not include message content"}

      {:error, reason} ->
        {:error, reason}

      _other ->
        {:error, "synthesis response payload did not match chat completions content"}
    end
  end

  defp normalize_content(content) when is_binary(content) do
    {:ok, String.trim(content)}
  end

  defp normalize_content(content) when is_list(content) do
    content
    |> Enum.map(&extract_content_part/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
    |> String.trim()
    |> then(&{:ok, &1})
  end

  defp normalize_content(_content) do
    {:error, "synthesis response content was not text"}
  end

  defp extract_content_part(%{"text" => text}) when is_binary(text), do: text
  defp extract_content_part(%{text: text}) when is_binary(text), do: text

  defp extract_content_part(%{"type" => "text", "text" => text}) when is_binary(text), do: text
  defp extract_content_part(%{type: "text", text: text}) when is_binary(text), do: text

  defp extract_content_part(%{"type" => "output_text", "text" => text}) when is_binary(text),
    do: text

  defp extract_content_part(%{type: "output_text", text: text}) when is_binary(text), do: text
  defp extract_content_part(_part), do: ""

  defp response_message(body, fallback) do
    error = read_key(body, "error")

    cond do
      is_binary(read_key(error, "message")) ->
        read_key(error, "message")

      is_binary(read_key(body, "message")) ->
        read_key(body, "message")

      true ->
        fallback
    end
  end

  defp choice_finish_reason(body) do
    case read_key(body, "choices") do
      [choice | _] -> read_key(choice, "finish_reason")
      _ -> nil
    end
  end

  defp body_model(body) do
    read_key(body, "model")
  end

  defp env_or_default(nil, default), do: default
  defp env_or_default(env_name, default), do: System.get_env(env_name) || default

  defp maybe_put(payload, _key, nil), do: payload
  defp maybe_put(payload, key, value), do: Map.put(payload, key, value)

  defp read_key(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, atom_key(key))
  end

  defp read_key(_value, _key), do: nil

  defp atom_key("choices"), do: :choices
  defp atom_key("error"), do: :error
  defp atom_key("finish_reason"), do: :finish_reason
  defp atom_key("id"), do: :id
  defp atom_key("message"), do: :message
  defp atom_key("model"), do: :model
  defp atom_key("usage"), do: :usage
  defp atom_key("content"), do: :content
  defp atom_key(_key), do: nil

  defp hash(value) do
    Canonical.hash(value)
  end
end
