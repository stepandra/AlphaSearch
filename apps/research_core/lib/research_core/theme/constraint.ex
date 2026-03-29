defmodule ResearchCore.Theme.Constraint do
  @moduledoc """
  Represents a heuristic constraint extracted from theme text.

  The `description` field captures the constraint text. The optional `kind`
  field is a best-effort classification (e.g., `:technical`, `:scope`,
  `:temporal`).
  """

  @enforce_keys [:description]
  defstruct [:description, :kind]

  @type kind :: :technical | :scope | :temporal | :methodological | atom()

  @type t :: %__MODULE__{
          description: String.t(),
          kind: kind() | nil
        }
end
