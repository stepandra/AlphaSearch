defmodule ResearchObservability.MixProject do
  use Mix.Project

  def project do
    [
      app: :research_observability,
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
      mod: {ResearchObservability.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:telemetry_poller, "~> 1.0"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_exporter, "~> 1.10"},
      {:opentelemetry_telemetry, "~> 1.1"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry_oban, "~> 1.2"},
      {:opentelemetry_bandit, "~> 0.3.0"}
    ]
  end
end
