defmodule ResearchObservabilityRuntimeFoundationTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../../..", __DIR__)

  test "research_observability declares the shared telemetry and tracing dependencies" do
    mix_contents = mix_file_contents("research_observability")

    assert mix_contents =~ "{:telemetry_metrics,"
    assert mix_contents =~ "{:telemetry_metrics_prometheus_core,"
    assert mix_contents =~ "{:telemetry_poller,"
    assert mix_contents =~ "{:opentelemetry,"
    assert mix_contents =~ "{:opentelemetry_exporter,"
    assert mix_contents =~ "{:opentelemetry_telemetry,"
    assert mix_contents =~ "{:opentelemetry_phoenix,"
    assert mix_contents =~ "{:opentelemetry_ecto,"
    assert mix_contents =~ "{:opentelemetry_oban,"
    assert mix_contents =~ "{:opentelemetry_bandit,"
  end

  test "root config exposes observability defaults for metrics and tracing" do
    assert Application.fetch_env!(:research_observability, :service_name) == "research_platform"
    assert Application.fetch_env!(:research_observability, :telemetry_poller_period) == 10_000
    assert Application.fetch_env!(:research_observability, :prometheus_metrics_path) == "/metrics"
    assert Application.fetch_env!(:research_observability, :prometheus_metrics_port) == 9_568
    assert Application.fetch_env!(:opentelemetry, :span_processor) == :batch
    assert Application.fetch_env!(:opentelemetry, :traces_exporter) == :none
    assert Application.fetch_env!(:opentelemetry_exporter, :otlp_protocol) == :http_protobuf
  end

  defp mix_file_contents(app_name) do
    Path.join([@repo_root, "apps", app_name, "mix.exs"])
    |> File.read!()
  end
end
