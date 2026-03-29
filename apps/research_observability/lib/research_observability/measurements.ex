defmodule ResearchObservability.Measurements do
  @moduledoc """
  Periodic measurements owned by the observability boundary.
  """

  @spec default_measurements() :: [tuple()]
  def default_measurements do
    [{__MODULE__, :dispatch_vm_metrics, []}]
  end

  @spec dispatch_vm_metrics() :: :ok
  def dispatch_vm_metrics do
    :telemetry.execute([:vm, :memory], %{total: :erlang.memory(:total)}, %{})

    :telemetry.execute(
      [:vm, :total_run_queue_lengths],
      %{
        total: :erlang.statistics(:total_run_queue_lengths)
      },
      %{}
    )

    :ok
  end
end
