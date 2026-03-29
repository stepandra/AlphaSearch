defmodule ResearchJobs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Oban, Application.fetch_env!(:research_jobs, Oban)}
    ]

    opts = [strategy: :one_for_one, name: ResearchJobs.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
