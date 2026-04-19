defmodule ResearchCore.Synthesis.RunState do
  @moduledoc """
  Lifecycle states for persisted synthesis runs.
  """

  @states [:pending, :running, :completed, :validation_failed, :provider_failed]

  @type t :: :pending | :running | :completed | :validation_failed | :provider_failed

  @spec all() :: [t()]
  def all, do: @states

  @spec valid?(term()) :: boolean()
  def valid?(value), do: value in @states
end
