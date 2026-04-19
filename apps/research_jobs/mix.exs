defmodule ResearchJobs.MixProject do
  use Mix.Project

  def project do
    [
      app: :research_jobs,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ResearchJobs.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:instructor, "~> 0.1.0"},
      {:oban, "~> 2.21"},
      {:nimble_options, "~> 1.1"},
      {:req, "~> 0.5"},
      {:research_core, in_umbrella: true},
      {:research_store, in_umbrella: true},
      {:research_observability, in_umbrella: true}
    ]
  end
end
