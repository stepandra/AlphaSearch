defmodule ResearchJobs.Synthesis.Providers.FakeTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Canonical
  alias ResearchJobs.Synthesis.ProviderResponse
  alias ResearchJobs.Synthesis.Providers.Fake

  test "hashes the full request spec canonically" do
    request_spec = %{prompt: "prompt-body", package_digest: "digest-1"}

    assert {:ok, %ProviderResponse{} = response} =
             Fake.synthesize(request_spec, content: "## Executive Summary\nOK")

    assert response.request_hash == Canonical.hash(request_spec)
    assert response.response_hash == Canonical.hash("## Executive Summary\nOK")
  end
end
