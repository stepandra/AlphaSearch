defmodule ResearchCore.Strategy.ValidationHint do
  @moduledoc """
  Suggested validation direction without turning it into a full backtest plan.
  """

  @enforce_keys [:kind, :description]
  defstruct [:kind, :description, :priority, blockers: []]

  @type priority :: :high | :medium | :low | nil

  @type t :: %__MODULE__{
          kind: atom(),
          description: String.t(),
          priority: priority(),
          blockers: [String.t()]
        }
end
