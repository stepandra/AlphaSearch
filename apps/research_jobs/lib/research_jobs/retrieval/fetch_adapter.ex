defmodule ResearchJobs.Retrieval.FetchAdapter do
  @moduledoc """
  Boundary behaviour for provider-backed fetch adapters.

  Concrete provider modules will implement this callback in later steps.
  """

  alias ResearchCore.Retrieval.{FetchRequest, FetchResult, ProviderError}

  @callback fetch(FetchRequest.t(), keyword()) ::
              {:ok, FetchResult.t()} | {:error, ProviderError.t()}
end
