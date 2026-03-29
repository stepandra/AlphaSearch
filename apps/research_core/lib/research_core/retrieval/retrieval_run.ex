defmodule ResearchCore.Retrieval.RetrievalRun do
  @moduledoc """
  Represents one retrieval pass across search and fetch requests.

  A retrieval run aggregates the explicit requests issued during the pass,
  their normalized provider results, any surfaced provider errors, and the
  optional fetch outputs produced for selected URLs.
  """

  alias ResearchCore.Retrieval.{
    FetchRequest,
    FetchResult,
    ProviderError,
    ProviderResult,
    SearchRequest
  }

  @enforce_keys [:id]
  defstruct [
    :id,
    :started_at,
    :completed_at,
    search_requests: [],
    provider_results: [],
    provider_errors: [],
    fetch_requests: [],
    fetch_results: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          search_requests: [SearchRequest.t()],
          provider_results: [ProviderResult.t()],
          provider_errors: [ProviderError.t()],
          fetch_requests: [FetchRequest.t()],
          fetch_results: [FetchResult.t()],
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil
        }
end
