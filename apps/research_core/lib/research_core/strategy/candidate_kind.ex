defmodule ResearchCore.Strategy.CandidateKind do
  @moduledoc """
  High-level candidate source/quality buckets before a strategy becomes a spec.
  """

  @type t ::
          :directly_specified_strategy
          | :formula_backed_incomplete_strategy
          | :analog_transfer_candidate
          | :speculative_not_backtestable

  @values [
    :directly_specified_strategy,
    :formula_backed_incomplete_strategy,
    :analog_transfer_candidate,
    :speculative_not_backtestable
  ]

  @spec values() :: [t()]
  def values, do: @values

  @spec valid?(term()) :: boolean()
  def valid?(value), do: value in @values
end
