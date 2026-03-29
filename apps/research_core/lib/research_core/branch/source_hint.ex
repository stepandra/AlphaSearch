defmodule ResearchCore.Branch.SourceHint do
  @moduledoc """
  Represents a suggested source or venue for a search query.

  The `label` field contains the source name (e.g., "SSRN", "arXiv",
  "Kalshi", "Polymarket").
  """

  @enforce_keys [:label]
  defstruct [:label]

  @type t :: %__MODULE__{
          label: String.t()
        }
end
