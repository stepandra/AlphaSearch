defmodule ResearchJobs.Retrieval.SearchAdapter do
  @moduledoc """
  Boundary behaviour for provider-backed search adapters.

  Concrete provider modules will implement this callback in later steps.
  """

  alias ResearchCore.Retrieval.{ProviderError, ProviderResult, SearchRequest}

  @callback search(SearchRequest.t(), keyword()) ::
              {:ok, ProviderResult.t()} | {:error, ProviderError.t()}
end
