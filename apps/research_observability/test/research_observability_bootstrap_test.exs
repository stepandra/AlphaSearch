defmodule ResearchObservabilityBootstrapTest do
  use ExUnit.Case, async: false

  @repo_root Path.expand("../../..", __DIR__)

  test "research_observability boots the shared telemetry supervisor" do
    assert {:ok, _apps} = Application.ensure_all_started(:research_observability)

    assert Process.whereis(ResearchObservability.Supervisor)

    assert Enum.any?(Supervisor.which_children(ResearchObservability.Supervisor), fn
             {ResearchObservability.Telemetry, _pid, :supervisor,
              [ResearchObservability.Telemetry]} ->
               true

             _child ->
               false
           end)
  end

  test "public bootstrap API starts telemetry poller and reporter children" do
    child_spec =
      ResearchObservability.telemetry_child_spec(
        id: {:observability_bootstrap, __MODULE__},
        name: nil,
        reporter_name: :research_observability_test_metrics,
        metrics: [{ResearchObservability.Metrics, :vm_metrics, []}],
        measurements: []
      )

    pid = start_supervised!(child_spec)

    children = Supervisor.which_children(pid)

    assert Enum.any?(children, fn {id, _child, _type, _modules} -> id == :telemetry_poller end)

    assert Enum.any?(children, fn {id, _child, _type, _modules} ->
             id == :research_observability_test_metrics
           end)

    ResearchObservability.Measurements.dispatch_vm_metrics()

    scrape = TelemetryMetricsPrometheus.Core.scrape(:research_observability_test_metrics)

    assert scrape =~ "vm_memory_total"
    assert scrape =~ "vm_total_run_queue_lengths"
  end

  test "root config exposes bootstrap telemetry and tracing defaults" do
    telemetry_opts =
      Application.fetch_env!(:research_observability, ResearchObservability.Telemetry)

    assert telemetry_opts[:reporter_name] == :research_platform_metrics

    assert telemetry_opts[:metrics] == [
             {ResearchObservability.Metrics, :phoenix_metrics, []},
             {ResearchObservability.Metrics, :repo_metrics, ["research_store.repo"]},
             {ResearchObservability.Metrics, :vm_metrics, []}
           ]

    assert telemetry_opts[:measurements] == [
             {ResearchObservability.Measurements, :default_measurements, []}
           ]

    tracing_opts = Application.fetch_env!(:research_observability, ResearchObservability.Tracing)

    assert tracing_opts[:phoenix][:adapter] == :bandit
    assert tracing_opts[:phoenix][:endpoint_prefix] == [:phoenix, :endpoint]
    assert tracing_opts[:phoenix][:liveview] == true
    assert tracing_opts[:bandit] == []
    assert tracing_opts[:ecto_event_prefixes] == [[:research_store, :repo]]
    assert tracing_opts[:oban] == :disabled

    assert :ok == ResearchObservability.setup_tracing(tracing_opts)
  end

  test "research_web no longer owns telemetry deps or its own telemetry supervisor" do
    web_application = repo_file("apps/research_web/lib/research_web/application.ex")
    web_mix = repo_file("apps/research_web/mix.exs")

    refute web_application =~ "ResearchWebWeb.Telemetry"
    refute web_mix =~ "{:telemetry_metrics,"
    refute web_mix =~ "{:telemetry_poller,"
  end

  defp repo_file(path) do
    Path.join(@repo_root, path)
    |> File.read!()
  end
end
