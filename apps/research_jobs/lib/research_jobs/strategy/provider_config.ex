defmodule ResearchJobs.Strategy.ProviderConfig do
  @moduledoc """
  Reads strategy extraction provider configuration from application config.
  """

  @app :research_jobs

  @type t :: %{
          default_provider: module(),
          llm: %{
            adapter: module(),
            api_key_env: String.t(),
            api_path: String.t(),
            api_url: String.t(),
            api_url_env: String.t() | nil,
            default_model: String.t(),
            http_options: keyword(),
            max_retries: non_neg_integer(),
            mode: atom(),
            model_env: String.t()
          }
        }

  @spec config() :: t()
  def config do
    @app
    |> Application.fetch_env!(__MODULE__)
    |> normalize()
  end

  @spec default_provider() :: module()
  def default_provider do
    config().default_provider
  end

  @spec llm() :: map()
  def llm do
    config().llm
  end

  defp normalize(options) do
    llm_options = Keyword.fetch!(options, :llm)

    %{
      default_provider: Keyword.fetch!(options, :default_provider),
      llm: %{
        adapter: Keyword.fetch!(llm_options, :adapter),
        api_key_env: Keyword.fetch!(llm_options, :api_key_env),
        api_path: Keyword.fetch!(llm_options, :api_path),
        api_url: Keyword.fetch!(llm_options, :api_url),
        api_url_env: Keyword.get(llm_options, :api_url_env),
        default_model: Keyword.fetch!(llm_options, :default_model),
        http_options: Keyword.get(llm_options, :http_options, []),
        max_retries: Keyword.get(llm_options, :max_retries, 0),
        mode: Keyword.get(llm_options, :mode, :json_schema),
        model_env: Keyword.fetch!(llm_options, :model_env)
      }
    }
  end
end
