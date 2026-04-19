defmodule ResearchJobs.Strategy.Providers.Stub do
  @moduledoc """
  Explicit non-production provider used when no strategy extraction provider is configured.
  """

  @behaviour ResearchJobs.Strategy.Provider

  alias ResearchJobs.Strategy.ProviderError

  @impl true
  def extract_formulas(_request_spec, _opts) do
    {:error,
     %ProviderError{
       provider: "stub",
       reason: :not_configured,
       message: "no strategy extraction provider is configured for this environment",
       details: %{}
     }}
  end

  @impl true
  def extract_strategies(_request_spec, _opts) do
    {:error,
     %ProviderError{
       provider: "stub",
       reason: :not_configured,
       message: "no strategy extraction provider is configured for this environment",
       details: %{}
     }}
  end
end
