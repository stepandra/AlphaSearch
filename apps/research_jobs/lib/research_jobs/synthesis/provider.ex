defmodule ResearchJobs.Synthesis.Provider do
  @moduledoc """
  Narrow provider boundary for synthesis execution.
  """

  alias ResearchJobs.Synthesis.{ProviderError, ProviderResponse}

  @callback synthesize(map(), keyword()) ::
              {:ok, ProviderResponse.t()} | {:error, ProviderError.t()}
end
