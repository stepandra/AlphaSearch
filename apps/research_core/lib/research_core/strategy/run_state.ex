defmodule ResearchCore.Strategy.RunState do
  @moduledoc """
  Lifecycle states for persisted strategy extraction runs.
  """

  @type t :: :pending | :running | :completed | :provider_failed | :validation_failed

  @values [:pending, :running, :completed, :provider_failed, :validation_failed]

  @spec values() :: [t()]
  def values, do: @values

  @spec valid?(term()) :: boolean()
  def valid?(value), do: value in @values
end
