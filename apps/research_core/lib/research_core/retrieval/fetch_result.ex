defmodule ResearchCore.Retrieval.FetchResult do
  @moduledoc """
  Represents the outcome of one fetch request.

  The result is explicit about whether the fetch succeeded or failed and keeps
  either the fetched document or the structured provider error.
  """

  alias ResearchCore.Retrieval.{FetchRequest, FetchedDocument, ProviderError}

  @enforce_keys [:request, :status]
  defstruct [:request, :status, :document, :error]

  @type t :: %__MODULE__{
          request: FetchRequest.t(),
          status: atom(),
          document: FetchedDocument.t() | nil,
          error: ProviderError.t() | nil
        }
end
