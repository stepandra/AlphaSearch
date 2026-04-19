defmodule ResearchJobs.Synthesis.Providers.Stub do
  @moduledoc """
  Explicit non-production provider used when no real synthesis provider is configured.
  """

  @behaviour ResearchJobs.Synthesis.Provider

  alias ResearchJobs.Synthesis.ProviderError

  @impl true
  def synthesize(_request_spec, _opts) do
    {:error,
     %ProviderError{
       provider: "stub",
       reason: :provider_not_configured,
       message: "no synthesis provider is configured for this environment",
       details: %{}
     }}
  end
end
