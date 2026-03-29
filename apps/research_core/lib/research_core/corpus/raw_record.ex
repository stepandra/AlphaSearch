defmodule ResearchCore.Corpus.RawRecord do
  @moduledoc """
  Raw corpus material assembled from retrieval outputs and optional extraction.
  """

  alias ResearchCore.Branch.Branch
  alias ResearchCore.Retrieval.{FetchedDocument, NormalizedSearchHit}
  alias ResearchCore.Theme.Normalized

  @enforce_keys [:id, :search_hit]
  defstruct [
    :id,
    :search_hit,
    :fetched_document,
    :retrieval_run_id,
    :branch,
    :theme,
    :split_from_id,
    raw_fields: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          search_hit: NormalizedSearchHit.t(),
          fetched_document: FetchedDocument.t() | nil,
          retrieval_run_id: String.t() | nil,
          branch: Branch.t() | nil,
          theme: Normalized.t() | nil,
          split_from_id: String.t() | nil,
          raw_fields: map()
        }
end
