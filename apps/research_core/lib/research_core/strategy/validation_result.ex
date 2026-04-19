defmodule ResearchCore.Strategy.ValidationResult do
  @moduledoc """
  Validation output for a strategy extraction run.
  """

  @enforce_keys [:valid?, :accepted_formula_ids, :accepted_strategy_ids]
  defstruct [
    :id,
    :strategy_extraction_run_id,
    :validated_at,
    valid?: false,
    fatal_errors: [],
    warnings: [],
    rejected_formulas: [],
    rejected_candidates: [],
    duplicate_groups: [],
    accepted_formula_ids: [],
    accepted_strategy_ids: []
  ]

  @type validation_issue :: %{
          required(:type) => atom(),
          required(:message) => String.t(),
          optional(:severity) => :fatal | :warning,
          optional(:details) => map()
        }

  @type t :: %__MODULE__{
          id: String.t() | nil,
          strategy_extraction_run_id: String.t() | nil,
          validated_at: DateTime.t() | nil,
          valid?: boolean(),
          fatal_errors: [validation_issue()],
          warnings: [validation_issue()],
          rejected_formulas: [map()],
          rejected_candidates: [map()],
          duplicate_groups: [map()],
          accepted_formula_ids: [String.t()],
          accepted_strategy_ids: [String.t()]
        }
end
