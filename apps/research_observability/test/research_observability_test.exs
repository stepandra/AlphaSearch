defmodule ResearchObservabilityTest do
  use ExUnit.Case, async: true

  test "exposes a public telemetry child spec helper" do
    spec = ResearchObservability.telemetry_child_spec(id: :test_observability, name: nil)

    assert spec.id == :test_observability
    assert match?({ResearchObservability.Telemetry, :start_link, [_]}, spec.start)
  end
end
