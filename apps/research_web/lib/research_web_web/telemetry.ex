defmodule ResearchWebWeb.Telemetry do
  @moduledoc false

  def metrics do
    ResearchObservability.Metrics.default_metrics(repo_prefix: "research_store.repo")
  end

  def periodic_measurements do
    ResearchObservability.Measurements.default_measurements()
  end
end
