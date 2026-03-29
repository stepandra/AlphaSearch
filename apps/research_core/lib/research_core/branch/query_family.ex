defmodule ResearchCore.Branch.QueryFamily do
  @moduledoc """
  Represents a family of related search queries sharing a common search strategy.

  Each family has a `kind` (e.g., `:precision`, `:recall`), a `rationale`
  explaining why this family exists for its branch, optional target
  `source_families`, and a list of explicit `queries`.
  """

  alias ResearchCore.Branch.{QueryFamilyKind, SearchQuery, SourceFamily}

  @enforce_keys [:kind, :rationale]
  defstruct [:kind, :rationale, source_families: [], queries: []]

  @type t :: %__MODULE__{
          kind: QueryFamilyKind.t(),
          rationale: String.t(),
          source_families: [SourceFamily.t()],
          queries: [SearchQuery.t()]
        }
end
