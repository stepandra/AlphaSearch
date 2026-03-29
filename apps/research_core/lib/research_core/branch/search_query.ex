defmodule ResearchCore.Branch.SearchQuery do
  @moduledoc """
  Represents an explicit search query string with optional source hints and
  inspectable source-scoping provenance.

  The `text` field is the literal query to be issued. The `source_hints`
  list suggests venues or databases where this query may be most productive.
  The remaining fields track whether the query is generic or source-scoped,
  which source family it targets, the scoped pattern that produced it, and
  which branch emitted it.
  """

  alias ResearchCore.Branch.{BranchKind, SourceFamily, SourceHint}

  @enforce_keys [:text]
  defstruct [
    :text,
    :source_family,
    :scoped_pattern,
    :branch_kind,
    :branch_label,
    scope_type: :generic,
    source_hints: []
  ]

  @type t :: %__MODULE__{
          text: String.t(),
          source_hints: [SourceHint.t()],
          scope_type: :generic | :source_scoped,
          source_family: SourceFamily.t() | nil,
          scoped_pattern: String.t() | nil,
          branch_kind: BranchKind.t() | nil,
          branch_label: String.t() | nil
        }
end
