defmodule ResearchCore.Strategy.StrategyReadiness do
  @moduledoc """
  Backtest-readiness states for normalized strategy specs.
  """

  @type t ::
          :ready_for_backtest
          | :needs_feature_build
          | :needs_formula_completion
          | :needs_data_mapping
          | :reject

  @values [
    :ready_for_backtest,
    :needs_feature_build,
    :needs_formula_completion,
    :needs_data_mapping,
    :reject
  ]

  @spec values() :: [t()]
  def values, do: @values

  @spec valid?(term()) :: boolean()
  def valid?(value), do: value in @values
end
