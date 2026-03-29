defmodule ResearchCore.Retrieval.SearchRequest do
  @moduledoc """
  Represents one provider-targeted search request.

  The request preserves the original upstream `SearchQuery` plus the resolved
  provider name and any per-request result limit selected by policy.
  """

  alias ResearchCore.Branch.SearchQuery

  @enforce_keys [:provider, :query]
  defstruct [:provider, :query, :max_results]

  @type t :: %__MODULE__{
          provider: atom(),
          query: SearchQuery.t(),
          max_results: pos_integer() | nil
        }
end
