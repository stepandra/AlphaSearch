defmodule ResearchCore.Retrieval.ProviderResult do
  @moduledoc """
  Represents one successful provider response after normalization.

  The result keeps the original request, the normalized hits derived from the
  provider response, and the raw payload or payload subset retained for audit.
  """

  alias ResearchCore.Retrieval.{NormalizedSearchHit, SearchRequest}

  @enforce_keys [:provider, :request]
  defstruct [:provider, :request, :raw_payload, hits: []]

  @type t :: %__MODULE__{
          provider: atom(),
          request: SearchRequest.t(),
          hits: [NormalizedSearchHit.t()],
          raw_payload: term() | nil
        }
end
