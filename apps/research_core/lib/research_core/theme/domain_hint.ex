defmodule ResearchCore.Theme.DomainHint do
  @moduledoc """
  Represents a domain hint extracted from a research theme.

  The `label` field contains a canonicalized domain identifier
  (e.g., "prediction-markets", "options-pricing").
  """

  @enforce_keys [:label]
  defstruct [:label]

  @type t :: %__MODULE__{
          label: String.t()
        }
end
