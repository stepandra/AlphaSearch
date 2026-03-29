defmodule ResearchCore.Retrieval.FetchRequest do
  @moduledoc """
  Represents one provider-targeted fetch request for a selected search hit.

  The request keeps the fetch provider, the target URL, and the originating
  normalized search hit so downstream stages can retain provenance.
  """

  alias ResearchCore.Retrieval.NormalizedSearchHit

  @enforce_keys [:provider, :url, :source_hit]
  defstruct [:provider, :url, :source_hit]

  @type t :: %__MODULE__{
          provider: atom(),
          url: String.t(),
          source_hit: NormalizedSearchHit.t()
        }
end
