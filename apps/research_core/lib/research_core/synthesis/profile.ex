defmodule ResearchCore.Synthesis.Profile do
  @moduledoc """
  Versioned, explicit report profile definition.
  """

  alias ResearchCore.Synthesis.SectionSpec

  @enforce_keys [
    :id,
    :version,
    :name,
    :section_specs,
    :citation_rules,
    :formula_rules,
    :anti_goals,
    :output_format
  ]
  defstruct [
    :id,
    :version,
    :name,
    :summary,
    :section_specs,
    :citation_rules,
    :formula_rules,
    :anti_goals,
    :output_format,
    include_background?: true,
    allow_quarantine_summary?: false,
    citation_key_prefix: "REC_",
    citation_key_width: 4,
    disallowed_sections: []
  ]

  @type output_format :: :markdown

  @type t :: %__MODULE__{
          id: String.t(),
          version: pos_integer(),
          name: String.t(),
          summary: String.t() | nil,
          section_specs: [SectionSpec.t()],
          citation_rules: [String.t()],
          formula_rules: [String.t()],
          anti_goals: [String.t()],
          output_format: output_format(),
          include_background?: boolean(),
          allow_quarantine_summary?: boolean(),
          citation_key_prefix: String.t(),
          citation_key_width: pos_integer(),
          disallowed_sections: [String.t()]
        }
end
