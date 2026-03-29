defmodule ResearchCore.Corpus.RecordClassification do
  @moduledoc """
  Supported corpus buckets emitted by the QA layer.
  """

  @classifications [:accepted_core, :accepted_analog, :background, :quarantine, :discard]

  @type t :: :accepted_core | :accepted_analog | :background | :quarantine | :discard

  @spec all() :: [t()]
  def all, do: @classifications

  @spec valid?(term()) :: boolean()
  def valid?(value), do: value in @classifications
end
