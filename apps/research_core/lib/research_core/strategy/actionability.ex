defmodule ResearchCore.Strategy.Actionability do
  @moduledoc """
  How soon a validated strategy should move downstream.
  """

  @type t :: :immediate | :near_term | :exploratory | :background_only

  @values [:immediate, :near_term, :exploratory, :background_only]

  @spec values() :: [t()]
  def values, do: @values

  @spec valid?(term()) :: boolean()
  def valid?(value), do: value in @values
end
