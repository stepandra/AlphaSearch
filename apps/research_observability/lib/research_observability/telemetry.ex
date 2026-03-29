defmodule ResearchObservability.Telemetry do
  @moduledoc """
  Generic telemetry supervisor used by bounded apps without introducing cycles.
  """

  use Supervisor

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    id = Keyword.get(opts, :id, __MODULE__)
    start_opts = Keyword.delete(opts, :id)

    %{
      id: id,
      start: {__MODULE__, :start_link, [start_opts]},
      type: :supervisor
    }
  end

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    case name do
      nil -> Supervisor.start_link(__MODULE__, opts)
      name -> Supervisor.start_link(__MODULE__, opts, name: name)
    end
  end

  @impl true
  def init(opts) do
    metrics = resolve_items(Keyword.get(opts, :metrics, []))
    measurements = resolve_items(Keyword.get(opts, :measurements, []))

    children =
      [
        {:telemetry_poller,
         measurements: measurements, period: Keyword.get(opts, :period, telemetry_poller_period())}
      ] ++ reporter_children(metrics, opts)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp reporter_children([], _opts), do: []

  defp reporter_children(metrics, opts) do
    [
      {TelemetryMetricsPrometheus.Core,
       name: Keyword.get(opts, :reporter_name, :research_platform_metrics),
       metrics: metrics,
       start_async: Keyword.get(opts, :reporter_start_async, false)}
    ]
  end

  defp telemetry_poller_period do
    Application.fetch_env!(:research_observability, :telemetry_poller_period)
  end

  defp resolve_items(providers) do
    providers
    |> List.wrap()
    |> Enum.flat_map(&resolve_item/1)
  end

  defp resolve_item({module, function, arguments})
       when is_atom(module) and is_atom(function) and is_list(arguments) do
    apply(module, function, arguments)
  end

  defp resolve_item(function) when is_function(function, 0) do
    function.()
  end

  defp resolve_item(items) when is_list(items) do
    items
  end

  defp resolve_item(item) do
    [item]
  end
end
