defmodule ResearchCore.Synthesis.SectionSpec do
  @moduledoc """
  One ordered section requirement inside a synthesis profile.
  """

  @enforce_keys [:id, :heading, :allowed_subsets, :guidance]
  defstruct [
    :id,
    :heading,
    :allowed_subsets,
    :guidance,
    optional?: false
  ]

  @type record_subset :: :accepted_core | :accepted_analog | :background | :quarantine_summary

  @type t :: %__MODULE__{
          id: atom(),
          heading: String.t(),
          allowed_subsets: [record_subset()],
          guidance: String.t(),
          optional?: boolean()
        }
end
