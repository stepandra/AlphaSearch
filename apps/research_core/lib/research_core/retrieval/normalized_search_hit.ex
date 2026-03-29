defmodule ResearchCore.Retrieval.NormalizedSearchHit do
  @moduledoc """
  Represents one provider result normalized into the shared retrieval shape.

  The struct keeps provider provenance, the original query, provider rank,
  display fields, and the raw provider payload fragment used to derive the hit.
  """

  alias ResearchCore.Branch.SearchQuery

  @enforce_keys [:provider, :query, :rank, :title, :url]
  defstruct [
    :provider,
    :query,
    :rank,
    :title,
    :url,
    :snippet,
    :raw_payload,
    fetch_status: :not_fetched
  ]

  @type t :: %__MODULE__{
          provider: atom(),
          query: SearchQuery.t(),
          rank: pos_integer(),
          title: String.t(),
          url: String.t(),
          snippet: String.t() | nil,
          raw_payload: term() | nil,
          fetch_status: atom()
        }
end
