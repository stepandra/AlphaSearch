defmodule ResearchCore.Strategy.DataRequirement do
  @moduledoc """
  Dataset or market feed dependency needed for validation/backtesting.
  """

  @enforce_keys [:name, :description, :mapping_status]
  defstruct [:name, :description, :mapping_status, :source, citation_keys: []]

  @type mapping_status :: :mapped | :needs_mapping | :unknown

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          mapping_status: mapping_status(),
          source: String.t() | nil,
          citation_keys: [String.t()]
        }
end
