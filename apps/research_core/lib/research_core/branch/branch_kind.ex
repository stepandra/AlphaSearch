defmodule ResearchCore.Branch.BranchKind do
  @moduledoc """
  Enumerates the supported branch categories for research theme expansion.

  Each kind represents a different angle from which to explore a normalized
  research theme:

  - `:direct` — the theme stated verbatim
  - `:narrower` — a more specific sub-topic
  - `:broader` — a wider framing
  - `:analog` — a parallel domain with transferable patterns
  - `:mechanism` — focuses on the causal mechanism
  - `:method` — focuses on the analytical method
  """

  @kinds [:direct, :narrower, :broader, :analog, :mechanism, :method]

  @type t :: :direct | :narrower | :broader | :analog | :mechanism | :method

  @doc "Returns the ordered list of all supported branch kinds."
  @spec all() :: [t()]
  def all, do: @kinds

  @doc "Returns `true` if `kind` is a supported branch kind."
  @spec valid?(atom()) :: boolean()
  def valid?(kind) when kind in @kinds, do: true
  def valid?(_kind), do: false
end
