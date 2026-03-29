defmodule ResearchCore.Branch.QueryFamilyKind do
  @moduledoc """
  Enumerates the supported query family categories.

  Each kind represents a different search strategy:

  - `:precision` — exact, narrow search terms
  - `:recall` — broad terms for wider coverage
  - `:synonym_alias` — alternative terminology and aliases
  - `:literature_format` — academic / publication-specific phrasing
  - `:venue_specific` — venue or platform names in queries
  - `:source_scoped` — reserved family for explicit source-scoped query variants
  """

  @kinds [
    :precision,
    :recall,
    :synonym_alias,
    :literature_format,
    :venue_specific,
    :source_scoped
  ]

  @type t ::
          :precision
          | :recall
          | :synonym_alias
          | :literature_format
          | :venue_specific
          | :source_scoped

  @doc "Returns the ordered list of all supported query family kinds."
  @spec all() :: [t()]
  def all, do: @kinds

  @doc "Returns `true` if `kind` is a supported query family kind."
  @spec valid?(atom()) :: boolean()
  def valid?(kind) when kind in @kinds, do: true
  def valid?(_kind), do: false
end
