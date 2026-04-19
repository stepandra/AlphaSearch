defmodule ResearchJobs.Synthesis.ProviderError do
  @moduledoc """
  Machine-readable provider failure.
  """

  @enforce_keys [:provider, :reason, :message]
  defstruct [:provider, :reason, :message, :details, retryable?: false]

  @type t :: %__MODULE__{
          provider: String.t(),
          reason: atom(),
          message: String.t(),
          details: map() | nil,
          retryable?: boolean()
        }
end
