defmodule ResearchCore.Evidence.Document do
  @moduledoc """
  Canonical source document identity for evidence extraction.
  """

  @enforce_keys [:id, :content_hash]
  defstruct [
    :id,
    :source_uri,
    :content_hash,
    :mime_type,
    :title,
    :parser,
    :parser_version,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          source_uri: String.t() | nil,
          content_hash: String.t(),
          mime_type: String.t() | nil,
          title: String.t() | nil,
          parser: atom() | nil,
          parser_version: String.t() | nil,
          metadata: map()
        }
end
