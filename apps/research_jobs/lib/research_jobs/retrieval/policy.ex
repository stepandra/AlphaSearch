defmodule ResearchJobs.Retrieval.Policy do
  @moduledoc """
  Validates retrieval execution policy for the jobs layer.

  This module stays limited to policy shape and defaults. It does not execute
  provider requests or encode adapter-specific behavior.
  """

  alias ResearchJobs.Retrieval.ProviderConfig

  @search_provider_choices [:serper, :brave, :tavily, :exa]
  @fetch_provider_choices [:jina]

  @schema NimbleOptions.new!(
            search_provider_order: [
              type: {:custom, __MODULE__, :validate_search_provider_order, []}
            ],
            fetch_provider: [
              type: {:in, @fetch_provider_choices}
            ],
            req_options: [
              type: :keyword_list
            ],
            max_results_per_query: [
              type: :pos_integer,
              default: 10
            ],
            fallback_enabled: [
              type: :boolean,
              default: true
            ],
            fetch_enabled: [
              type: :boolean,
              default: true
            ],
            fetch_limit_per_query: [
              type: :pos_integer,
              default: 3
            ]
          )

  @enforce_keys [
    :search_provider_order,
    :fetch_provider,
    :req_options,
    :max_results_per_query,
    :fallback_enabled,
    :fetch_enabled,
    :fetch_limit_per_query
  ]
  defstruct @enforce_keys

  @type search_provider_name :: :serper | :brave | :tavily | :exa
  @type fetch_provider_name :: :jina

  @type t :: %__MODULE__{
          search_provider_order: [search_provider_name()],
          fetch_provider: fetch_provider_name(),
          req_options: keyword(),
          max_results_per_query: pos_integer(),
          fallback_enabled: boolean(),
          fetch_enabled: boolean(),
          fetch_limit_per_query: pos_integer()
        }

  @spec default() :: t()
  def default do
    new!([])
  end

  @spec new(keyword()) :: {:ok, t()} | {:error, NimbleOptions.ValidationError.t()}
  def new(options \\ []) do
    options =
      runtime_defaults()
      |> Keyword.merge(options)

    with {:ok, validated} <- NimbleOptions.validate(options, @schema) do
      {:ok, struct!(__MODULE__, validated)}
    end
  end

  @spec new!(keyword()) :: t()
  def new!(options \\ []) do
    case new(options) do
      {:ok, policy} -> policy
      {:error, error} -> raise error
    end
  end

  @doc false
  @spec validate_search_provider_order(term()) ::
          {:ok, [search_provider_name()]} | {:error, String.t()}
  def validate_search_provider_order(order) when is_list(order) do
    cond do
      order == [] ->
        {:error, "expected a non-empty list of supported search providers"}

      Enum.any?(order, &(&1 not in @search_provider_choices)) ->
        {:error,
         "expected search providers from #{inspect(@search_provider_choices)}, got: #{inspect(order)}"}

      Enum.uniq(order) != order ->
        {:error,
         "expected search providers to be unique in priority order, got duplicates in: #{inspect(order)}"}

      true ->
        {:ok, order}
    end
  end

  def validate_search_provider_order(value) do
    {:error, "expected a list of supported search providers, got: #{inspect(value)}"}
  end

  defp runtime_defaults do
    [
      search_provider_order: ProviderConfig.search_provider_order(),
      fetch_provider: ProviderConfig.fetch_provider(),
      req_options: ProviderConfig.req_options()
    ]
  end
end
