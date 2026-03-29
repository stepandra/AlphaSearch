defmodule ResearchObservability do
  @moduledoc """
  Public bootstrap entrypoints for telemetry, metrics, and tracing ownership.
  """

  @spec telemetry_child_spec(keyword()) :: Supervisor.child_spec()
  def telemetry_child_spec(opts \\ []) do
    ResearchObservability.Telemetry.child_spec(opts)
  end

  @spec configured_telemetry_child_spec() :: Supervisor.child_spec()
  def configured_telemetry_child_spec do
    :research_observability
    |> Application.get_env(ResearchObservability.Telemetry, [])
    |> telemetry_child_spec()
  end

  @spec setup_tracing(keyword()) :: :ok
  def setup_tracing(opts \\ []) do
    ResearchObservability.Tracing.setup(opts)
  end
end
