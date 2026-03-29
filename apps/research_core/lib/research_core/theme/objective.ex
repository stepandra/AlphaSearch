defmodule ResearchCore.Theme.Objective do
  @moduledoc """
  Represents a research objective extracted from a theme.

  The `description` field captures what the research aims to achieve or discover.
  """

  @enforce_keys [:description]
  defstruct [:description]

  @type t :: %__MODULE__{
          description: String.t()
        }
end
