defmodule ResearchCore.Branch.Branch do
  @moduledoc """
  Represents a research branch expanded from a normalized theme.

  Each branch has a `kind` (e.g., `:direct`, `:analog`), a human-readable
  `label`, a `rationale` for why this branch exists, a `theme_relation`
  describing how it connects to the source theme, an optional
  source-targeting rationale plus preferred source families, and a list
  of `query_families` containing explicit search queries.
  """

  alias ResearchCore.Branch.{BranchKind, QueryFamily, SourceFamily}

  @enforce_keys [:kind, :label, :rationale, :theme_relation]
  defstruct [
    :kind,
    :label,
    :rationale,
    :theme_relation,
    :source_targeting_rationale,
    preferred_source_families: [],
    query_families: []
  ]

  @type t :: %__MODULE__{
          kind: BranchKind.t(),
          label: String.t(),
          rationale: String.t(),
          theme_relation: String.t(),
          preferred_source_families: [SourceFamily.t()],
          source_targeting_rationale: String.t() | nil,
          query_families: [QueryFamily.t()]
        }
end
