defmodule ResearchCore.Evidence.BoundingBox do
  @moduledoc """
  Page-local bounding box reported by a document parser.
  """

  @enforce_keys [:page, :x, :y, :width, :height]
  defstruct [:page, :x, :y, :width, :height]

  @type t :: %__MODULE__{
          page: pos_integer(),
          x: float(),
          y: float(),
          width: float(),
          height: float()
        }
end
