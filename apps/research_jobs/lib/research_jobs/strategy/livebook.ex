defmodule ResearchJobs.Strategy.Livebook do
  @moduledoc """
  Notebook-facing helpers for explicit strategy extraction walkthroughs.
  """

  alias ResearchCore.Strategy
  alias ResearchCore.Strategy.InputPackage
  alias ResearchJobs.Strategy.Models.{FormulaExtractionBatch, StrategyExtractionBatch}
  alias ResearchJobs.Strategy.{PromptBuilder, ProviderConfig, Runner}
  alias ResearchStore.{CorpusRegistry, SynthesisRegistry}

  @credential_envs %{
    openai_api_key: "OPENAI_API_KEY",
    openai_api_url: "OPENAI_API_URL",
    synthesis_llm_model: "SYNTHESIS_LLM_MODEL",
    strategy_llm_model: "STRATEGY_LLM_MODEL",
    serper_api_key: "SERPER_API_KEY",
    brave_api_key: "BRAVE_API_KEY",
    tavily_api_key: "TAVILY_API_KEY",
    exa_api_key: "EXA_API_KEY",
    jina_api_key: "JINA_API_KEY"
  }

  @type context :: %{
          required(:bundle) => map(),
          required(:synthesis_run) => map() | struct(),
          required(:artifact) => map() | struct(),
          required(:validation_result) => map() | struct()
        }

  @spec credential_template() :: %{required(atom()) => String.t() | nil}
  def credential_template do
    Map.new(@credential_envs, fn {key, _env} -> {key, nil} end)
  end

  @spec apply_credentials(map()) :: %{applied: [map()], skipped: [map()]}
  def apply_credentials(credentials) when is_map(credentials) do
    Enum.reduce(@credential_envs, %{applied: [], skipped: []}, fn {key, env_name}, acc ->
      case credential_value(credentials, key, env_name) do
        nil ->
          %{acc | skipped: acc.skipped ++ [%{key: key, env: env_name}]}

        value ->
          System.put_env(env_name, value)

          %{
            acc
            | applied:
                acc.applied ++
                  [
                    %{
                      key: key,
                      env: env_name,
                      value: masked_value(key, value)
                    }
                  ]
          }
      end
    end)
  end

  @spec config_summary() :: map()
  def config_summary do
    retrieval_config = ResearchJobs.Retrieval.ProviderConfig.config()
    synthesis_config = ResearchJobs.Synthesis.ProviderConfig.config()
    strategy_config = ProviderConfig.config()

    %{
      retrieval: %{
        search_provider_order: retrieval_config.search_provider_order,
        fetch_provider: retrieval_config.fetch_provider,
        providers:
          Map.new(retrieval_config.providers, fn {provider_name, provider_settings} ->
            {provider_name,
             %{
               api_key_env: provider_settings.api_key_env,
               api_key_configured?: present_env?(provider_settings.api_key_env),
               endpoint: provider_settings.endpoint
             }}
          end)
      },
      strategy: %{
        default_provider: strategy_config.default_provider,
        llm: %{
          api_key_env: strategy_config.llm.api_key_env,
          api_key_configured?: present_env?(strategy_config.llm.api_key_env),
          api_url_env: strategy_config.llm.api_url_env,
          api_url: env_or_default(strategy_config.llm.api_url_env, strategy_config.llm.api_url),
          model_env: strategy_config.llm.model_env,
          model: env_or_default(strategy_config.llm.model_env, strategy_config.llm.default_model),
          mode: strategy_config.llm.mode
        }
      },
      synthesis: %{
        default_provider: synthesis_config.default_provider,
        llm: %{
          api_key_env: synthesis_config.llm.api_key_env,
          api_key_configured?: present_env?(synthesis_config.llm.api_key_env),
          api_url_env: synthesis_config.llm.api_url_env,
          api_url: env_or_default(synthesis_config.llm.api_url_env, synthesis_config.llm.api_url),
          model_env: synthesis_config.llm.model_env,
          model:
            env_or_default(
              synthesis_config.llm.model_env,
              synthesis_config.llm.default_model
            ),
          temperature: synthesis_config.llm.temperature
        }
      }
    }
  end

  @spec default_strategy_provider() :: module()
  def default_strategy_provider do
    ProviderConfig.default_provider()
  end

  @spec load_persisted_context(String.t(), String.t()) ::
          {:ok, context()} | {:error, term()}
  def load_persisted_context(snapshot_id, synthesis_profile_id)
      when is_binary(snapshot_id) and is_binary(synthesis_profile_id) do
    with {:ok, bundle} <- CorpusRegistry.load_snapshot(snapshot_id),
         %ResearchCore.Synthesis.Artifact{} = artifact <-
           SynthesisRegistry.successful_artifact_for_snapshot(snapshot_id, synthesis_profile_id),
         %ResearchCore.Synthesis.Run{} = synthesis_run <-
           SynthesisRegistry.get_run(artifact.synthesis_run_id),
         %ResearchCore.Synthesis.ValidationResult{} = validation_result <-
           synthesis_run.validation_result do
      {:ok,
       %{
         bundle: bundle,
         synthesis_run: synthesis_run,
         artifact: artifact,
         validation_result: validation_result
       }}
    else
      nil ->
        {:error, {:missing_validated_synthesis_artifact, snapshot_id, synthesis_profile_id}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec load_persisted_context!(String.t(), String.t()) :: context()
  def load_persisted_context!(snapshot_id, synthesis_profile_id) do
    snapshot_id
    |> load_persisted_context(synthesis_profile_id)
    |> unwrap!()
  end

  @spec build_input_package(context(), keyword()) ::
          {:ok, InputPackage.t()} | {:error, term()}
  def build_input_package(context, opts \\ [])

  def build_input_package(
        %{
          bundle: bundle,
          synthesis_run: synthesis_run,
          artifact: artifact,
          validation_result: validation
        },
        opts
      )
      when is_list(opts) do
    Strategy.build_input_package(bundle, synthesis_run, artifact, validation, opts)
  end

  @spec build_input_package!(context(), keyword()) :: InputPackage.t()
  def build_input_package!(context, opts \\ []) do
    context
    |> build_input_package(opts)
    |> unwrap!()
  end

  @spec build_formula_request(InputPackage.t()) :: map()
  def build_formula_request(%InputPackage{} = input_package) do
    PromptBuilder.build_formula_request(input_package)
  end

  @spec run_formula_extraction(InputPackage.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def run_formula_extraction(%InputPackage{} = input_package, opts \\ []) do
    provider = Keyword.get(opts, :provider, ProviderConfig.default_provider())
    provider_opts = Keyword.get(opts, :provider_opts, [])
    request_spec = build_formula_request(input_package)

    with {:ok, response} <- provider.extract_formulas(request_spec, provider_opts) do
      {:ok,
       %{
         request_spec: request_spec,
         provider_response: response,
         raw_candidates: FormulaExtractionBatch.to_maps(response.content)
       }}
    end
  end

  @spec run_formula_extraction!(InputPackage.t(), keyword()) :: map()
  def run_formula_extraction!(%InputPackage{} = input_package, opts \\ []) do
    input_package
    |> run_formula_extraction(opts)
    |> unwrap!()
  end

  @spec normalize_formula_candidates(InputPackage.t(), [map()]) :: map()
  def normalize_formula_candidates(%InputPackage{} = input_package, raw_formula_candidates)
      when is_list(raw_formula_candidates) do
    ResearchCore.Strategy.FormulaNormalizer.normalize(input_package, raw_formula_candidates)
  end

  @spec build_strategy_request(InputPackage.t(), list()) :: map()
  def build_strategy_request(%InputPackage{} = input_package, formulas) when is_list(formulas) do
    PromptBuilder.build_strategy_request(input_package, formulas)
  end

  @spec run_strategy_extraction(InputPackage.t(), list(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def run_strategy_extraction(%InputPackage{} = input_package, formulas, opts \\ [])
      when is_list(formulas) do
    provider = Keyword.get(opts, :provider, ProviderConfig.default_provider())
    provider_opts = Keyword.get(opts, :provider_opts, [])
    request_spec = build_strategy_request(input_package, formulas)

    with {:ok, response} <- provider.extract_strategies(request_spec, provider_opts) do
      {:ok,
       %{
         request_spec: request_spec,
         provider_response: response,
         raw_candidates: StrategyExtractionBatch.to_maps(response.content)
       }}
    end
  end

  @spec run_strategy_extraction!(InputPackage.t(), list(), keyword()) :: map()
  def run_strategy_extraction!(%InputPackage{} = input_package, formulas, opts \\ [])
      when is_list(formulas) do
    input_package
    |> run_strategy_extraction(formulas, opts)
    |> unwrap!()
  end

  @spec normalize(InputPackage.t(), [map()], [map()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def normalize(
        %InputPackage{} = input_package,
        raw_formula_candidates,
        raw_strategy_candidates,
        opts \\ []
      )
      when is_list(raw_formula_candidates) and is_list(raw_strategy_candidates) do
    Strategy.normalize(input_package, raw_formula_candidates, raw_strategy_candidates, opts)
  end

  @spec normalize!(InputPackage.t(), [map()], [map()], keyword()) :: map()
  def normalize!(
        %InputPackage{} = input_package,
        raw_formula_candidates,
        raw_strategy_candidates,
        opts \\ []
      )
      when is_list(raw_formula_candidates) and is_list(raw_strategy_candidates) do
    input_package
    |> normalize(raw_formula_candidates, raw_strategy_candidates, opts)
    |> unwrap!()
  end

  @spec persist_strategy_run(String.t(), String.t(), keyword()) ::
          {:ok, ResearchCore.Strategy.ExtractionRun.t()}
          | {:error, ResearchCore.Strategy.ExtractionRun.t()}
          | {:error, term()}
  def persist_strategy_run(snapshot_id, synthesis_profile_id, opts \\ []) do
    Runner.run(snapshot_id, synthesis_profile_id, opts)
  end

  defp credential_value(credentials, key, env_name) do
    credentials[key] ||
      credentials[Atom.to_string(key)] ||
      credentials[env_name] ||
      credentials[String.downcase(env_name)]
      |> normalize_string()
  end

  defp present_env?(env_name) when is_binary(env_name) do
    env_name
    |> System.get_env()
    |> normalize_string()
    |> Kernel.!=(nil)
  end

  defp env_or_default(nil, default), do: default

  defp env_or_default(env_name, default) when is_binary(env_name) do
    normalize_string(System.get_env(env_name)) || default
  end

  defp masked_value(key, value)
       when key in [
              :openai_api_key,
              :serper_api_key,
              :brave_api_key,
              :tavily_api_key,
              :exa_api_key,
              :jina_api_key
            ] do
    case String.length(value) do
      length when length <= 8 -> String.duplicate("*", length)
      length -> String.slice(value, 0, 4) <> "..." <> String.slice(value, length - 4, 4)
    end
  end

  defp masked_value(_key, value), do: value

  defp normalize_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_string(_value), do: nil

  defp unwrap!({:ok, value}), do: value

  defp unwrap!({:error, reason}) do
    raise ArgumentError, "strategy livebook helper failed: #{inspect(reason, pretty: true)}"
  end
end
