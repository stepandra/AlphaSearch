defmodule ResearchCore.Retrieval.FetchedDocument do
  @moduledoc """
  Represents cleaned page content fetched for a selected URL.

  The document stores the cleaned body, its format, optional title, and the
  raw provider payload retained for debugging or provenance.
  """

  @enforce_keys [:url, :content, :content_format]
  defstruct [:url, :content, :content_format, :title, :raw_payload, :fetched_at]

  @type t :: %__MODULE__{
          url: String.t(),
          content: String.t(),
          content_format: atom(),
          title: String.t() | nil,
          raw_payload: term() | nil,
          fetched_at: DateTime.t() | nil
        }
end
