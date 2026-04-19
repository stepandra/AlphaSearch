defmodule ResearchJobs.Synthesis.ProviderResponse do
  @moduledoc """
  Raw provider response plus normalized metadata captured for auditability.
  """

  @enforce_keys [:provider, :model, :content]
  defstruct [
    :provider,
    :model,
    :content,
    :request_id,
    :response_id,
    :request_hash,
    :response_hash,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          provider: String.t(),
          model: String.t(),
          content: String.t(),
          request_id: String.t() | nil,
          response_id: String.t() | nil,
          request_hash: String.t() | nil,
          response_hash: String.t() | nil,
          metadata: map()
        }
end
