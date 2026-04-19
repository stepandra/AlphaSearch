defmodule ResearchCore.Strategy.FeatureRequirement do
  @moduledoc """
  Feature input needed to operationalize a strategy.
  """

  @enforce_keys [:name, :description, :status]
  defstruct [:name, :description, :status, :source, citation_keys: []]

  @type status :: :available | :needs_build | :unknown

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          status: status(),
          source: String.t() | nil,
          citation_keys: [String.t()]
        }
end
