defmodule ResearchCore.Synthesis.Run do
  @moduledoc """
  Persisted synthesis execution record.
  """

  alias ResearchCore.Synthesis.{Artifact, InputPackage, RunState, ValidationResult}

  @enforce_keys [:id, :corpus_snapshot_id, :profile_id, :state]
  defstruct [
    :id,
    :corpus_snapshot_id,
    :normalized_theme_id,
    :research_branch_id,
    :profile_id,
    :state,
    :input_package,
    :request_spec,
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
    :artifact
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          corpus_snapshot_id: String.t(),
          normalized_theme_id: String.t() | nil,
          research_branch_id: String.t() | nil,
          profile_id: String.t(),
          state: RunState.t(),
          input_package: InputPackage.t() | map() | nil,
          request_spec: map() | nil,
          provider_name: String.t() | nil,
          provider_model: String.t() | nil,
          provider_request_id: String.t() | nil,
          provider_response_id: String.t() | nil,
          provider_request_hash: String.t() | nil,
          provider_response_hash: String.t() | nil,
          provider_metadata: map() | nil,
          provider_failure: map() | nil,
          raw_provider_output: String.t() | nil,
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          validation_result: ValidationResult.t() | nil,
          artifact: Artifact.t() | nil
        }
end
