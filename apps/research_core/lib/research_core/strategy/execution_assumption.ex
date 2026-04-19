defmodule ResearchCore.Strategy.ExecutionAssumption do
  @moduledoc """
  Explicit assumption a downstream backtest or reviewer must honor.
  """

  @enforce_keys [:kind, :description]
  defstruct [:kind, :description, blocking?: false, citation_keys: []]

  @type t :: %__MODULE__{
          kind: atom(),
          description: String.t(),
          blocking?: boolean(),
          citation_keys: [String.t()]
        }
end
