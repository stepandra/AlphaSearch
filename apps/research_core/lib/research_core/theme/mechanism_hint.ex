defmodule ResearchCore.Theme.MechanismHint do
  @moduledoc """
  Represents a mechanism hint extracted from a research theme.

  The `label` field contains a canonicalized mechanism identifier
  (e.g., "order-book-state", "cross-exchange-routing").
  """

  @enforce_keys [:label]
  defstruct [:label]

  @type t :: %__MODULE__{
          label: String.t()
        }
end
