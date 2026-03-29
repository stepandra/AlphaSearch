defmodule ResearchJobs.Retrieval.ProviderConfig do
  @moduledoc """
  Reads the retrieval provider scaffold from application config.

  The returned values stay explicit and provider-specific so later adapter and
  policy modules can validate and consume them without hiding provider behavior.
  """

  @app :research_jobs

  @type provider_name :: :serper | :jina | :brave | :tavily | :exa
  @type provider_settings :: %{
          required(:api_key_env) => String.t(),
          required(:endpoint) => String.t()
        }
  @type t :: %{
          search_provider_order: [provider_name()],
          fetch_provider: provider_name(),
          req_options: keyword(),
          providers: %{provider_name() => provider_settings()}
        }

  @spec config() :: t()
  def config do
    @app
    |> Application.fetch_env!(__MODULE__)
    |> normalize()
  end

  @spec search_provider_order() :: [provider_name()]
  def search_provider_order do
    config().search_provider_order
  end

  @spec fetch_provider() :: provider_name()
  def fetch_provider do
    config().fetch_provider
  end

  @spec req_options() :: keyword()
  def req_options do
    config().req_options
  end

  @spec providers() :: %{provider_name() => provider_settings()}
  def providers do
    config().providers
  end

  @spec provider!(provider_name()) :: provider_settings()
  def provider!(provider_name) do
    Map.fetch!(providers(), provider_name)
  end

  @spec new_request(keyword()) :: Req.Request.t()
  def new_request(options \\ []) do
    req_options()
    |> Keyword.merge(options)
    |> Req.new()
  end

  defp normalize(options) do
    %{
      search_provider_order: Keyword.fetch!(options, :search_provider_order),
      fetch_provider: Keyword.fetch!(options, :fetch_provider),
      req_options: Keyword.fetch!(options, :req_options),
      providers:
        options
        |> Keyword.fetch!(:providers)
        |> Map.new(fn {provider_name, provider_options} ->
          {provider_name, Map.new(provider_options)}
        end)
    }
  end
end
