defmodule ResearchJobs.Retrieval.Pipeline do
  @moduledoc """
  Explicit search orchestration boundary for retrieval work in `research_jobs`.

  The pipeline validates and stores retrieval policy plus adapter modules, and
  it can execute upstream `SearchQuery` inputs through the configured search
  providers in priority order. Search fallback stays explicit and provider
  errors are preserved in the returned `RetrievalRun`.
  """

  alias ResearchCore.Branch.SearchQuery

  alias ResearchCore.Retrieval.{
    FetchRequest,
    FetchResult,
    NormalizedSearchHit,
    ProviderError,
    ProviderResult,
    RetrievalRun,
    SearchRequest
  }

  alias ResearchJobs.Retrieval.Policy

  @schema NimbleOptions.new!(
            policy: [
              type: {:struct, Policy}
            ],
            search_adapters: [
              type: {:map, :atom, :atom},
              default: %{}
            ],
            fetch_adapter: [
              type: {:or, [:atom, nil]},
              default: nil
            ]
          )

  @enforce_keys [:policy]
  defstruct [:policy, search_adapters: %{}, fetch_adapter: nil]

  @type search_adapter_registry :: %{optional(Policy.search_provider_name()) => module()}

  @type t :: %__MODULE__{
          policy: Policy.t(),
          search_adapters: search_adapter_registry(),
          fetch_adapter: module() | nil
        }

  @spec new(keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def new(options \\ []) do
    options =
      runtime_defaults()
      |> Keyword.merge(options)

    with {:ok, validated} <- NimbleOptions.validate(options, @schema),
         :ok <- validate_search_adapters(validated[:search_adapters], validated[:policy]),
         :ok <- validate_fetch_adapter(validated[:fetch_adapter]) do
      {:ok, struct!(__MODULE__, validated)}
    end
  end

  @spec new!(keyword()) :: t()
  def new!(options \\ []) do
    case new(options) do
      {:ok, pipeline} -> pipeline
      {:error, error} -> raise error
    end
  end

  @spec search(t(), [SearchQuery.t()]) :: RetrievalRun.t()
  def search(%__MODULE__{} = pipeline, queries) when is_list(queries) do
    started_at = timestamp()
    ordered_queries = source_scoped_first(queries)

    {search_requests, provider_results, search_errors} =
      Enum.reduce(ordered_queries, {[], [], []}, fn %SearchQuery{} = query,
                                                    {requests_acc, results_acc, errors_acc} ->
        {query_requests, query_result, query_errors} = search_query(pipeline, query)

        {
          requests_acc ++ query_requests,
          append_result(results_acc, query_result),
          errors_acc ++ query_errors
        }
      end)

    {provider_results, fetch_requests, fetch_results, fetch_errors} =
      maybe_fetch_provider_results(pipeline, provider_results)

    %RetrievalRun{
      id: run_id(),
      started_at: started_at,
      completed_at: timestamp(),
      search_requests: search_requests,
      provider_results: provider_results,
      provider_errors: search_errors ++ fetch_errors,
      fetch_requests: fetch_requests,
      fetch_results: fetch_results
    }
  end

  defp validate_search_adapters(search_adapters, %Policy{search_provider_order: provider_order}) do
    Enum.reduce_while(search_adapters, :ok, fn {provider_name, adapter_module}, :ok ->
      cond do
        provider_name not in provider_order ->
          {:halt,
           {:error,
            ArgumentError.exception(
              "search adapter #{inspect(provider_name)} is not in policy search_provider_order"
            )}}

        not Code.ensure_loaded?(adapter_module) or
            not function_exported?(adapter_module, :search, 2) ->
          {:halt,
           {:error,
            ArgumentError.exception(
              "search adapter #{inspect(adapter_module)} must export search/2"
            )}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp validate_fetch_adapter(nil), do: :ok

  defp validate_fetch_adapter(adapter_module) do
    if Code.ensure_loaded?(adapter_module) and function_exported?(adapter_module, :fetch, 2) do
      :ok
    else
      {:error,
       ArgumentError.exception("fetch adapter #{inspect(adapter_module)} must export fetch/2")}
    end
  end

  defp search_query(
         %__MODULE__{policy: %Policy{search_provider_order: provider_order} = policy} = pipeline,
         %SearchQuery{} = query
       ) do
    Enum.reduce_while(provider_order, {[], nil, []}, fn provider, {requests, _result, errors} ->
      request = %SearchRequest{
        provider: provider,
        query: query,
        max_results: policy.max_results_per_query
      }

      case execute_search_adapter(pipeline, request) do
        {:ok, %ProviderResult{} = result} ->
          {:halt, {requests ++ [request], result, errors}}

        {:error, %ProviderError{} = error} ->
          updated = {requests ++ [request], nil, errors ++ [error]}

          if policy.fallback_enabled do
            {:cont, updated}
          else
            {:halt, updated}
          end
      end
    end)
  end

  defp execute_search_adapter(
         %__MODULE__{policy: %Policy{req_options: req_options}, search_adapters: search_adapters},
         %SearchRequest{provider: provider} = request
       ) do
    case Map.fetch(search_adapters, provider) do
      {:ok, adapter_module} ->
        case adapter_module.search(request, req: Req.new(req_options)) do
          {:ok, %ProviderResult{} = result} ->
            {:ok, result}

          {:error, %ProviderError{} = error} ->
            {:error, error}

          other ->
            {:error,
             %ProviderError{
               provider: provider,
               request_kind: :search,
               reason: :invalid_adapter_response,
               message: "search adapter #{inspect(adapter_module)} returned an invalid response",
               raw_payload: other
             }}
        end

      :error ->
        {:error,
         %ProviderError{
           provider: provider,
           request_kind: :search,
           reason: :missing_adapter,
           message: "no search adapter is registered for #{inspect(provider)}"
         }}
    end
  end

  defp maybe_fetch_provider_results(
         %__MODULE__{policy: %Policy{fetch_enabled: false}},
         provider_results
       )
       when is_list(provider_results) do
    {provider_results, [], [], []}
  end

  defp maybe_fetch_provider_results(
         %__MODULE__{
           policy: %Policy{
             fetch_enabled: true,
             fetch_limit_per_query: fetch_limit_per_query,
             fetch_provider: fetch_provider
           }
         } = pipeline,
         provider_results
       )
       when is_list(provider_results) do
    fetch_requests =
      provider_results
      |> Enum.flat_map(fn %ProviderResult{} = result ->
        build_fetch_requests(result, fetch_limit_per_query, fetch_provider)
      end)
      |> deduplicate_fetch_requests()

    fetch_results = Enum.map(fetch_requests, &execute_fetch_adapter(pipeline, &1))
    fetch_errors = fetch_errors(fetch_results)

    {
      update_fetch_statuses(provider_results, fetch_results),
      fetch_requests,
      fetch_results,
      fetch_errors
    }
  end

  defp build_fetch_requests(
         %ProviderResult{} = result,
         fetch_limit_per_query,
         fetch_provider
       ) do
    result.hits
    |> Enum.take(fetch_limit_per_query)
    |> Enum.map(fn %NormalizedSearchHit{} = hit ->
      %FetchRequest{
        provider: fetch_provider,
        url: hit.url,
        source_hit: hit
      }
    end)
  end

  defp execute_fetch_adapter(
         %__MODULE__{policy: %Policy{req_options: req_options}, fetch_adapter: adapter_module},
         %FetchRequest{provider: provider} = request
       )
       when is_atom(adapter_module) and not is_nil(adapter_module) do
    case adapter_module.fetch(request, req: Req.new(req_options)) do
      {:ok, %FetchResult{} = result} ->
        result

      {:error, %ProviderError{} = error} ->
        %FetchResult{
          request: request,
          status: :error,
          error: error
        }

      other ->
        %FetchResult{
          request: request,
          status: :error,
          error: %ProviderError{
            provider: provider,
            request_kind: :fetch,
            reason: :invalid_adapter_response,
            message: "fetch adapter #{inspect(adapter_module)} returned an invalid response",
            raw_payload: other
          }
        }
    end
  end

  defp execute_fetch_adapter(
         %__MODULE__{fetch_adapter: nil},
         %FetchRequest{provider: provider} = request
       ) do
    %FetchResult{
      request: request,
      status: :error,
      error: %ProviderError{
        provider: provider,
        request_kind: :fetch,
        reason: :missing_adapter,
        message: "no fetch adapter is registered for #{inspect(provider)}"
      }
    }
  end

  defp deduplicate_fetch_requests(fetch_requests) do
    {deduplicated, _seen_urls} =
      Enum.reduce(fetch_requests, {[], MapSet.new()}, fn %FetchRequest{} = request,
                                                         {requests_acc, seen_urls} ->
        if MapSet.member?(seen_urls, request.url) do
          {requests_acc, seen_urls}
        else
          {requests_acc ++ [request], MapSet.put(seen_urls, request.url)}
        end
      end)

    deduplicated
  end

  defp update_fetch_statuses(provider_results, []), do: provider_results

  defp update_fetch_statuses(provider_results, fetch_results) when is_list(provider_results) do
    statuses_by_url =
      Map.new(fetch_results, fn %FetchResult{
                                  request: %FetchRequest{url: url},
                                  status: status
                                } ->
        {url, status}
      end)

    Enum.map(provider_results, fn %ProviderResult{} = result ->
      updated_hits =
        Enum.map(result.hits, fn %NormalizedSearchHit{} = hit ->
          case Map.fetch(statuses_by_url, hit.url) do
            {:ok, status} -> %NormalizedSearchHit{hit | fetch_status: status}
            :error -> hit
          end
        end)

      %ProviderResult{result | hits: updated_hits}
    end)
  end

  defp fetch_errors(fetch_results) when is_list(fetch_results) do
    Enum.flat_map(fetch_results, fn
      %FetchResult{status: :error, error: %ProviderError{} = error} -> [error]
      %FetchResult{} -> []
    end)
  end

  defp runtime_defaults do
    [policy: Policy.default()]
  end

  defp source_scoped_first(queries) do
    {scoped, generic} = Enum.split_with(queries, &source_scoped_query?/1)
    scoped ++ generic
  end

  defp source_scoped_query?(%SearchQuery{scope_type: :source_scoped}), do: true
  defp source_scoped_query?(%SearchQuery{}), do: false

  defp append_result(results, nil), do: results
  defp append_result(results, result), do: results ++ [result]

  defp run_id do
    "retrieval-run-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.truncate(:microsecond)
  end
end
