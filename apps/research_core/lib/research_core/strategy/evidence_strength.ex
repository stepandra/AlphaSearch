defmodule ResearchCore.Strategy.EvidenceStrength do
  @moduledoc """
  Coarse evidence quality buckets for extracted strategies.
  """

  @type t :: :strong | :moderate | :weak | :speculative

  @values [:strong, :moderate, :weak, :speculative]

  @spec values() :: [t()]
  def values, do: @values

  @spec valid?(term()) :: boolean()
  def valid?(value), do: value in @values
end
