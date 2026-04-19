defmodule ResearchCore.Synthesis.ValidationResult do
  @moduledoc """
  Machine-readable report validation output.
  """

  @enforce_keys [
    :valid?,
    :structural_errors,
    :citation_errors,
    :formula_errors,
    :cited_keys,
    :allowed_keys
  ]
  defstruct [
    :id,
    :synthesis_run_id,
    :validated_at,
    :metadata,
    valid?: false,
    structural_errors: [],
    citation_errors: [],
    formula_errors: [],
    cited_keys: [],
    allowed_keys: [],
    unknown_keys: []
  ]

  @type validation_error :: %{
          required(:type) => atom(),
          required(:message) => String.t(),
          optional(:details) => map()
        }

  @type t :: %__MODULE__{
          id: String.t() | nil,
          synthesis_run_id: String.t() | nil,
          valid?: boolean(),
          structural_errors: [validation_error()],
          citation_errors: [validation_error()],
          formula_errors: [validation_error()],
          cited_keys: [String.t()],
          allowed_keys: [String.t()],
          unknown_keys: [String.t()],
          validated_at: DateTime.t() | nil,
          metadata: map() | nil
        }
end
