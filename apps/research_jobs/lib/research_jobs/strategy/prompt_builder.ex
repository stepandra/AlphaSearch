defmodule ResearchJobs.Strategy.PromptBuilder do
  @moduledoc """
  Builds explicit, phase-scoped request specs for formula and strategy extraction.
  """

  alias ResearchCore.Strategy.InputPackage

  @spec build_formula_request(InputPackage.t()) :: map()
  def build_formula_request(%InputPackage{} = input_package) do
    sections =
      section_payload(input_package, [
        :executive_summary,
        :ranked_important_papers_and_findings,
        :taxonomy_and_thematic_grouping,
        :reusable_formulas,
        :open_gaps,
        :next_prototype_recommendations
      ])

    records =
      Map.take(
        input_package.resolved_records,
        Enum.flat_map(sections, & &1.cited_keys) |> Enum.uniq()
      )

    %{
      phase: :formula_extraction,
      objective:
        "Extract exact and partial formulas only from validated synthesis sections and cited records. Preserve missing-equation uncertainty.",
      required_fields: [
        :formula_text,
        :exact,
        :partial,
        :blocked,
        :role,
        :source_section_ids,
        :supporting_citation_keys,
        :symbol_glossary,
        :notes
      ],
      optional_fields: [:evidence_pairs],
      sections: sections,
      records: records,
      prompt: render_prompt(:formula_extraction, sections, records, [])
    }
  end

  @spec build_strategy_request(InputPackage.t(), [ResearchCore.Strategy.FormulaCandidate.t()]) ::
          map()
  def build_strategy_request(%InputPackage{} = input_package, formulas) do
    sections =
      section_payload(input_package, [
        :executive_summary,
        :ranked_important_papers_and_findings,
        :taxonomy_and_thematic_grouping,
        :reusable_formulas,
        :open_gaps,
        :next_prototype_recommendations
      ])

    records =
      Map.take(
        input_package.resolved_records,
        Enum.flat_map(sections, & &1.cited_keys) |> Enum.uniq()
      )

    formula_payload = formula_payload(formulas)

    %{
      phase: :strategy_extraction,
      objective:
        "Convert validated synthesis conclusions into strategy candidates with explicit signals, evidence, assumptions, formula references, and testing hints.",
      required_fields: [
        :title,
        :thesis,
        :category,
        :candidate_kind,
        :market_or_domain_applicability,
        :direct_signal_or_rule,
        :entry_condition,
        :exit_condition,
        :formula_references,
        :required_features,
        :required_datasets,
        :execution_assumptions,
        :sizing_assumptions,
        :evidence_references,
        :conflicting_or_cautionary_evidence,
        :expected_edge_source,
        :validation_hints,
        :candidate_metrics,
        :falsification_idea,
        :source_section_ids,
        :notes
      ],
      optional_fields: [:evidence_pairs, :conflicting_evidence_pairs],
      sections: sections,
      formulas: formula_payload,
      records: records,
      prompt: render_prompt(:strategy_extraction, sections, records, formula_payload)
    }
  end

  defp section_payload(input_package, section_ids) do
    section_ids
    |> Enum.map(&Map.get(input_package.section_lookup, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn section ->
      %{
        id: section.id,
        heading: section.heading,
        cited_keys: section.cited_keys,
        body: section.body
      }
    end)
  end

  defp formula_payload(formulas) do
    Enum.map(formulas, fn formula ->
      %{
        id: formula.id,
        formula_text: formula.formula_text,
        exact?: formula.exact?,
        partial?: formula.partial?,
        blocked?: formula.blocked?,
        role: formula.role,
        supporting_citation_keys: formula.supporting_citation_keys
      }
    end)
  end

  defp render_prompt(phase, sections, records, formulas) do
    phase_guidance =
      case phase do
        :formula_extraction ->
          "Return only formulas that are explicitly supported by the cited report sections. Never upgrade ambiguous formulas to exact."

        :strategy_extraction ->
          "Return only testable strategy candidates that are supported by the cited report sections and available formulas. Reject narrative filler."
      end

    """
    You are extracting structured #{phase} output from a validated synthesis artifact.
    #{phase_guidance}

    Required behavior:
    - Use only citation keys that appear in the provided sections and records.
    - Preserve exact versus partial uncertainty explicitly.
    - When a formula or strategy relies on a specific section/citation pairing, include explicit evidence_pairs using {section_id, citation_key, quote?} instead of leaving provenance ambiguous.
    - Do not fabricate formulas, citations, or unsupported strategies.
     - Return structured data that matches the requested schema exactly.

    Sections:
    #{Jason.encode!(sections, pretty: true)}

    Records:
    #{Jason.encode!(records, pretty: true)}

    Available formulas:
    #{Jason.encode!(formulas, pretty: true)}
    """
  end
end
