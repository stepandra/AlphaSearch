defmodule ResearchCore.Strategy.ExtractionRun do
  @moduledoc """
  Persisted execution record for strategy-spec extraction.
  """

  alias ResearchCore.Strategy.{RunState, ValidationResult}

  @enforce_keys [
    :id,
    :corpus_snapshot_id,
    :synthesis_run_id,
    :synthesis_artifact_id,
    :synthesis_profile_id,
    :state
  ]
  defstruct [
    :id,
    :corpus_snapshot_id,
    :synthesis_run_id,
    :synthesis_artifact_id,
    :synthesis_profile_id,
    :normalized_theme_id,
    :research_branch_id,
    :state,
    :input_package,
    :formula_request_spec,
    :strategy_request_spec,
    :provider_name,
    :provider_model,
    :provider_request_id,
    :provider_response_id,
    :provider_request_hash,
    :provider_response_hash,
    :provider_metadata,
    :provider_failure,
    :raw_provider_output,
    :started_at,
    :completed_at,
    :validation_result,
    formulas: [],
    strategy_specs: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          corpus_snapshot_id: String.t(),
          synthesis_run_id: String.t(),
          synthesis_artifact_id: String.t(),
          synthesis_profile_id: String.t(),
          normalized_theme_id: String.t() | nil,
          research_branch_id: String.t() | nil,
          state: RunState.t(),
          input_package: map() | struct() | nil,
          formula_request_spec: map() | nil,
          strategy_request_spec: map() | nil,
          provider_name: String.t() | nil,
          provider_model: String.t() | nil,
          provider_request_id: String.t() | nil,
          provider_response_id: String.t() | nil,
          provider_request_hash: String.t() | nil,
          provider_response_hash: String.t() | nil,
          provider_metadata: map() | nil,
          provider_failure: map() | nil,
          raw_provider_output: map() | nil,
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          validation_result: ValidationResult.t() | nil,
          formulas: [ResearchCore.Strategy.FormulaCandidate.t()],
          strategy_specs: [ResearchCore.Strategy.StrategySpec.t()]
        }
end
