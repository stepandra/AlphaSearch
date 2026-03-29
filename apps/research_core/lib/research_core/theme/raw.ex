defmodule ResearchCore.Theme.Raw do
  @moduledoc """
  Represents an unprocessed research theme as received from human input.

  The `raw_text` field is the only required field and contains the original
  theme text exactly as submitted. Optional metadata tracks provenance.
  """

  @enforce_keys [:raw_text]
  defstruct [
    :raw_text,
    :source,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          raw_text: String.t(),
          source: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }
end
