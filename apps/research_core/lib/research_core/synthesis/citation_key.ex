defmodule ResearchCore.Synthesis.CitationKey do
  @moduledoc """
  Stable, report-facing citation handle for one included corpus record.
  """

  @enforce_keys [:key, :record_id, :classification, :ordinal]
  defstruct [:key, :record_id, :classification, :ordinal]

  @type t :: %__MODULE__{
          key: String.t(),
          record_id: String.t(),
          classification: :accepted_core | :accepted_analog | :background,
          ordinal: pos_integer()
        }
end
