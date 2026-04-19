defmodule ResearchCore.Strategy.Section do
  @moduledoc """
  Parsed synthesis section included in extraction scope.
  """

  @enforce_keys [:id, :heading, :body, :index, :cited_keys]
  defstruct [:id, :heading, :body, :index, cited_keys: []]

  @type t :: %__MODULE__{
          id: atom(),
          heading: String.t(),
          body: String.t(),
          index: non_neg_integer(),
          cited_keys: [String.t()]
        }
end
