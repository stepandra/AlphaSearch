defmodule ResearchJobs.Strategy.Providers.Instructor do
  @moduledoc """
  Live strategy extraction provider backed by Instructor.
  """

  @behaviour ResearchJobs.Strategy.Provider

  alias ResearchJobs.Strategy.Models.{FormulaExtractionBatch, StrategyExtractionBatch}
  alias ResearchJobs.Strategy.{ProviderConfig, ProviderError, ProviderResponse}
  alias ResearchCore.Canonical

  @impl true
  def extract_formulas(request_spec, opts) do
    request_spec
    |> run_completion(FormulaExtractionBatch, :formula_extraction, opts)
    |> normalize_response(request_spec, opts)
  end

  @impl true
  def extract_strategies(request_spec, opts) do
    request_spec
    |> run_completion(StrategyExtractionBatch, :strategy_extraction, opts)
    |> normalize_response(request_spec, opts)
  end

  defp run_completion(request_spec, response_model, phase, opts) do
    llm = ProviderConfig.llm()

    with {:ok, model} <- fetch_model(llm, opts),
         {:ok, instructor_config} <- instructor_config(llm, opts) do
      Instructor.chat_completion(
        [
          model: model,
          response_model: response_model,
          mode: Keyword.get(opts, :mode, llm.mode),
          max_retries: Keyword.get(opts, :max_retries, llm.max_retries),
          messages: messages(phase, request_spec)
        ],
        instructor_config
      )
    end
  end

  defp normalize_response({:ok, content}, request_spec, opts) do
    provider = Keyword.get(opts, :provider_name, "instructor")
    llm = ProviderConfig.llm()
    model = Keyword.get(opts, :model) || System.get_env(llm.model_env) || llm.default_model

    {:ok,
     %ProviderResponse{
       provider: provider,
       model: model,
       phase: content_phase(content),
       content: content,
       request_hash: hash(request_spec),
       response_hash: hash(content),
       metadata: %{
         adapter: provider_id(llm.adapter),
         mode: Keyword.get(opts, :mode, llm.mode)
       }
     }}
  end

  defp normalize_response({:error, %Ecto.Changeset{} = changeset}, _request_spec, _opts) do
    {:error,
     %ProviderError{
       provider: "instructor",
       reason: :invalid_provider_output,
       message: "strategy extraction output failed schema validation",
       details: %{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)}
     }}
  end

  defp normalize_response({:error, {:not_configured, reason}}, _request_spec, _opts) do
    {:error,
     %ProviderError{
       provider: "instructor",
       reason: :not_configured,
       message: reason,
       details: %{}
     }}
  end

  defp normalize_response({:error, reason}, _request_spec, _opts) when is_binary(reason) do
    {:error,
     %ProviderError{
       provider: "instructor",
       reason: :request_failed,
       message: reason,
       details: %{}
     }}
  end

  defp normalize_response({:error, reason}, _request_spec, _opts) do
    {:error,
     %ProviderError{
       provider: "instructor",
       reason: :request_failed,
       message: inspect(reason),
       details: %{reason: inspect(reason)}
     }}
  end

  defp fetch_model(llm, opts) do
    case Keyword.get(opts, :model) || System.get_env(llm.model_env) || llm.default_model do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:not_configured, "no strategy extraction model is configured"}}
    end
  end

  defp instructor_config(llm, opts) do
    api_key = Keyword.get(opts, :api_key) || System.get_env(llm.api_key_env)

    if is_binary(api_key) and api_key != "" do
      api_url = Keyword.get(opts, :api_url) || env_or_default(llm.api_url_env, llm.api_url)

      {:ok,
       [
         adapter: llm.adapter,
         api_key: api_key,
         api_url: api_url,
         api_path: llm.api_path,
         http_options: llm.http_options
       ]}
    else
      {:error, {:not_configured, "no strategy extraction API key is configured"}}
    end
  end

  defp messages(phase, request_spec) do
    [
      %{
        role: "system",
        content:
          "You extract machine-readable #{phase} output from validated research. Preserve uncertainty, never fabricate evidence, and return only schema-valid structured data."
      },
      %{
        role: "user",
        content: request_spec[:prompt] || Canonical.encode!(request_spec)
      }
    ]
  end

  defp content_phase(%FormulaExtractionBatch{}), do: :formula_extraction
  defp content_phase(%StrategyExtractionBatch{}), do: :strategy_extraction

  defp env_or_default(nil, default), do: default

  defp env_or_default(env_name, default) do
    System.get_env(env_name) || default
  end

  defp hash(value) do
    Canonical.hash(value)
  end

  defp provider_id(value) when is_atom(value), do: Atom.to_string(value)
  defp provider_id(value) when is_binary(value), do: value
  defp provider_id(value), do: Canonical.hash(value)
end
