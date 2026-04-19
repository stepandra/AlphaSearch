defmodule ResearchCore.Strategy.FormulaRole do
  @moduledoc """
  Roles a normalized formula can play inside a strategy candidate.
  """

  @type t ::
          :calibration
          | :execution
          | :arbitrage_or_coherence
          | :sizing
          | :behavioral_adjustment
          | :other

  @values [
    :calibration,
    :execution,
    :arbitrage_or_coherence,
    :sizing,
    :behavioral_adjustment,
    :other
  ]

  @spec values() :: [t()]
  def values, do: @values

  @spec valid?(term()) :: boolean()
  def valid?(value), do: value in @values
end
