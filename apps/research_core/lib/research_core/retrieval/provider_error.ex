defmodule ResearchCore.Retrieval.ProviderError do
  @moduledoc """
  Represents an explicit provider error surfaced during search or fetch work.

  Errors stay structured so later pipeline stages can preserve provider name,
  operation kind, retryability, and any raw payload details without guessing.
  """

  @enforce_keys [:provider, :request_kind, :reason]
  defstruct [:provider, :request_kind, :reason, :message, :status, :raw_payload, retryable: false]

  @type t :: %__MODULE__{
          provider: atom(),
          request_kind: atom(),
          reason: atom(),
          message: String.t() | nil,
          status: pos_integer() | nil,
          retryable: boolean(),
          raw_payload: term() | nil
        }
end
