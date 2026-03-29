defmodule ResearchObservability.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :ok =
      :research_observability
      |> Application.get_env(ResearchObservability.Tracing, [])
      |> ResearchObservability.setup_tracing()

    children = [
      ResearchObservability.configured_telemetry_child_spec()
    ]

    opts = [strategy: :one_for_one, name: ResearchObservability.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
