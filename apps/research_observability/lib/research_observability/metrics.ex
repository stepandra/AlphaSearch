defmodule ResearchObservability.Metrics do
  @moduledoc """
  Shared metric definitions for the research platform control plane.
  """

  import Telemetry.Metrics

  @spec default_metrics(keyword()) :: [Telemetry.Metrics.t()]
  def default_metrics(opts \\ []) do
    repo_prefix = Keyword.get(opts, :repo_prefix, "research_store.repo")

    phoenix_metrics() ++ repo_metrics(repo_prefix) ++ vm_metrics()
  end

  @spec phoenix_metrics() :: [Telemetry.Metrics.t()]
  def phoenix_metrics do
    [
      distribution("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1_000, 2_000]]
      ),
      distribution("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1_000, 2_000]]
      ),
      distribution("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1_000, 2_000]]
      ),
      distribution("phoenix.socket_connected.duration",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1_000, 2_000]]
      ),
      sum("phoenix.socket_drain.count"),
      distribution("phoenix.channel_joined.duration",
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1_000, 2_000]]
      ),
      distribution("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond},
        reporter_options: [buckets: [10, 50, 100, 250, 500, 1_000, 2_000]]
      )
    ]
  end

  @spec repo_metrics(String.t()) :: [Telemetry.Metrics.t()]
  def repo_metrics(repo_prefix) do
    [
      distribution("#{repo_prefix}.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements",
        reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1_000]]
      ),
      distribution("#{repo_prefix}.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database",
        reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1_000]]
      ),
      distribution("#{repo_prefix}.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query",
        reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1_000]]
      ),
      distribution("#{repo_prefix}.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection",
        reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1_000]]
      ),
      distribution("#{repo_prefix}.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query",
        reporter_options: [buckets: [1, 5, 10, 25, 50, 100, 250, 500, 1_000]]
      )
    ]
  end

  @spec vm_metrics() :: [Telemetry.Metrics.t()]
  def vm_metrics do
    [
      last_value("vm.memory.total", unit: {:byte, :byte}),
      last_value("vm.total_run_queue_lengths.total")
    ]
  end
end
