defmodule ResearchJobs.Strategy.ProviderResponse do
  @moduledoc """
  Provider response wrapper for either the formula or strategy extraction phase.
  """

  @enforce_keys [:provider, :model, :phase, :content]
  defstruct [
    :provider,
    :model,
    :phase,
    :content,
    :request_id,
    :response_id,
    :request_hash,
    :response_hash,
    metadata: %{}
  ]

  @type phase :: :formula_extraction | :strategy_extraction

  @type t :: %__MODULE__{
          provider: String.t(),
          model: String.t(),
          phase: phase(),
          content: struct(),
          request_id: String.t() | nil,
          response_id: String.t() | nil,
          request_hash: String.t() | nil,
          response_hash: String.t() | nil,
          metadata: map()
        }
end
