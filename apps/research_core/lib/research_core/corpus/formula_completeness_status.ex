defmodule ResearchCore.Corpus.FormulaCompletenessStatus do
  @moduledoc """
  Coarse formula-usability states for downstream synthesis.
  """

  @statuses [:exact, :partial, :referenced_only, :none, :unknown]

  @type t :: :exact | :partial | :referenced_only | :none | :unknown

  @spec all() :: [t()]
  def all, do: @statuses

  @spec valid?(term()) :: boolean()
  def valid?(value), do: value in @statuses
end
