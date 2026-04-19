defmodule ResearchJobs.Strategy.Provider do
  @moduledoc """
  Narrow provider boundary for strategy-spec extraction.
  """

  alias ResearchJobs.Strategy.{ProviderError, ProviderResponse}

  @callback extract_formulas(map(), keyword()) ::
              {:ok, ProviderResponse.t()} | {:error, ProviderError.t()}

  @callback extract_strategies(map(), keyword()) ::
              {:ok, ProviderResponse.t()} | {:error, ProviderError.t()}
end
