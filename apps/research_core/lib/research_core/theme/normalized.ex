defmodule ResearchCore.Theme.Normalized do
  @moduledoc """
  Represents a research theme after normalization.

  Contains the original input, normalized text, a current topic fallback,
  domain hints, mechanism hints, objective, heuristic constraints, and
  freeform notes.
  """

  alias ResearchCore.Theme.{Objective, Constraint, DomainHint, MechanismHint}

  @enforce_keys [:original_input, :normalized_text, :topic]
  defstruct [
    :original_input,
    :normalized_text,
    :topic,
    :objective,
    :notes,
    domain_hints: [],
    mechanism_hints: [],
    constraints: []
  ]

  @type t :: %__MODULE__{
          original_input: String.t(),
          normalized_text: String.t(),
          topic: String.t(),
          domain_hints: [DomainHint.t()],
          mechanism_hints: [MechanismHint.t()],
          objective: Objective.t() | nil,
          constraints: [Constraint.t()],
          notes: String.t() | nil
        }
end
