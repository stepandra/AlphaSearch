defmodule ResearchCore.Strategy.MetricHint do
  @moduledoc """
  Outcome or diagnostic metric that should be monitored during downstream validation.
  """

  @enforce_keys [:name, :description]
  defstruct [:name, :description, :direction]

  @type direction :: :maximize | :minimize | :monitor | nil

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          direction: direction()
        }
end
