defmodule ResearchCore.Synthesis.Profiles.LiteratureReviewV1 do
  @moduledoc """
  First concrete synthesis profile: a structured, citation-disciplined literature review.
  """

  alias ResearchCore.Synthesis.{Profile, SectionSpec}

  @spec definition() :: Profile.t()
  def definition do
    %Profile{
      id: "literature_review_v1",
      version: 1,
      name: "Structured Literature Review",
      summary:
        "Summarizes finalized evidence bundles into an explicit literature review artifact.",
      include_background?: true,
      allow_quarantine_summary?: true,
      output_format: :markdown,
      citation_rules: [
        "Use only the stable citation keys included in the package.",
        "Every ranked paper or concrete finding must cite at least one package key.",
        "Do not invent bibliography entries, footnotes, or external references.",
        "Unused citation keys are fine; phantom citation keys are invalid."
      ],
      formula_rules: [
        "Only reproduce exact formulas for records whose package entry says exact reusable formula text is available.",
        "If a record is partial, referenced_only, none, or unknown, say that exact formula text is unavailable rather than fabricating it.",
        "Do not upgrade a record from referenced formula metadata into an exact formula."
      ],
      anti_goals: [
        "Do not generate trading hypotheses.",
        "Do not score research branches.",
        "Do not recommend backtests or package backtest instructions.",
        "Do not cite any source outside the finalized snapshot."
      ],
      disallowed_sections: ["Hypothesis Candidates", "Trading Strategy", "Backtest Plan"],
      section_specs: [
        %SectionSpec{
          id: :executive_summary,
          heading: "Executive Summary",
          allowed_subsets: [:accepted_core, :accepted_analog, :background],
          guidance: "State the main evidence-backed takeaways and their confidence boundaries."
        },
        %SectionSpec{
          id: :ranked_findings,
          heading: "Ranked Important Papers and Findings",
          allowed_subsets: [:accepted_core, :accepted_analog],
          guidance:
            "Rank the most important records and explain why each matters for the research theme."
        },
        %SectionSpec{
          id: :taxonomy,
          heading: "Taxonomy and Thematic Grouping",
          allowed_subsets: [:accepted_core, :accepted_analog, :background],
          guidance: "Group the evidence into explicit themes, methods, or market analog clusters."
        },
        %SectionSpec{
          id: :reusable_formulas,
          heading: "Reusable Formulas",
          allowed_subsets: [:accepted_core, :accepted_analog, :background],
          guidance:
            "List reusable formulas only when the package says exact formula text is available; otherwise say exact text is unavailable."
        },
        %SectionSpec{
          id: :open_gaps,
          heading: "Open Gaps",
          allowed_subsets: [:accepted_core, :accepted_analog, :background],
          guidance:
            "Call out evidence gaps, missing contexts, or unresolved transferability risks."
        },
        %SectionSpec{
          id: :next_prototype_recommendations,
          heading: "Next Prototype Recommendations",
          allowed_subsets: [:accepted_core, :accepted_analog, :background],
          guidance: "Recommend research prototypes or follow-up work, not trading hypotheses."
        },
        %SectionSpec{
          id: :evidence_appendix,
          heading: "Evidence Appendix",
          allowed_subsets: [:accepted_core, :accepted_analog, :background],
          guidance:
            "Include a full evidence table or appendix covering all included package records."
        },
        %SectionSpec{
          id: :quarantine_summary,
          heading: "Quarantine Summary",
          allowed_subsets: [:quarantine_summary],
          guidance:
            "Optional metadata-only appendix summarizing quarantined records and why they were excluded.",
          optional?: true
        }
      ]
    }
  end
end
