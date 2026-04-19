defmodule ResearchCore.Strategy.StrategyCategory do
  @moduledoc """
  Supported strategy categories emitted by the strategy-spec extractor.
  """

  @type t ::
          :calibration_strategy
          | :execution_strategy
          | :coherence_arbitrage_strategy
          | :sizing_strategy
          | :behavioral_filter_strategy
          | :analog_transfer_strategy
          | :market_structure_strategy

  @values [
    :calibration_strategy,
    :execution_strategy,
    :coherence_arbitrage_strategy,
    :sizing_strategy,
    :behavioral_filter_strategy,
    :analog_transfer_strategy,
    :market_structure_strategy
  ]

  @spec values() :: [t()]
  def values, do: @values

  @spec valid?(term()) :: boolean()
  def valid?(value), do: value in @values
end
