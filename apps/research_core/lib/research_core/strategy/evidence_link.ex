defmodule ResearchCore.Strategy.EvidenceLink do
  @moduledoc """
  Traceable connection from a formula/spec back to a synthesis section and cited record.
  """

  @enforce_keys [:section_id, :section_heading, :citation_key, :record_id, :relation]
  defstruct [
    :section_id,
    :section_heading,
    :citation_key,
    :record_id,
    :relation,
    :quote,
    :note,
    provenance_reference: %{}
  ]

  @type relation ::
          :supports_formula
          | :supports_rule
          | :supports_thesis
          | :cautionary
          | :contradictory

  @type t :: %__MODULE__{
          section_id: atom(),
          section_heading: String.t(),
          citation_key: String.t(),
          record_id: String.t(),
          relation: relation(),
          quote: String.t() | nil,
          note: String.t() | nil,
          provenance_reference: map()
        }
end
