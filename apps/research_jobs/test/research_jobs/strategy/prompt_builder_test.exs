defmodule ResearchJobs.Strategy.PromptBuilderTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Strategy.{FormulaCandidate, InputPackage, Section}
  alias ResearchJobs.Strategy.Models.{Caster, FormulaExtractionBatch, StrategyExtractionBatch}
  alias ResearchJobs.Strategy.PromptBuilder

  test "includes all required synthesis sections in both extraction phases" do
    package = input_package_fixture()

    formula_request = PromptBuilder.build_formula_request(package)

    strategy_request =
      PromptBuilder.build_strategy_request(package, [formula_candidate_fixture()])

    assert Enum.map(formula_request.sections, & &1.id) == required_section_ids()
    assert Enum.map(strategy_request.sections, & &1.id) == required_section_ids()
    assert formula_request.optional_fields == [:evidence_pairs]
    assert strategy_request.optional_fields == [:evidence_pairs, :conflicting_evidence_pairs]
    assert is_binary(formula_request.prompt)
    assert is_binary(strategy_request.prompt)
  end

  test "batch models accept honest empty extraction results" do
    assert {:ok, %FormulaExtractionBatch{formulas: []}} =
             Caster.cast(FormulaExtractionBatch, %{formulas: []})

    assert {:ok, %StrategyExtractionBatch{strategies: []}} =
             Caster.cast(StrategyExtractionBatch, %{strategies: []})
  end

  defp input_package_fixture do
    sections =
      required_section_ids()
      |> Enum.with_index()
      |> Enum.map(fn {section_id, index} ->
        %Section{
          id: section_id,
          heading: Atom.to_string(section_id),
          body: "Section #{index} [REC_000#{index + 1}]",
          index: index,
          cited_keys: ["REC_000#{index + 1}"]
        }
      end)

    %InputPackage{
      corpus_snapshot_id: "snapshot-1",
      snapshot_finalized_at: ~U[2026-03-30 12:00:00Z],
      synthesis_run_id: "synthesis-run-1",
      synthesis_artifact_id: "artifact-1",
      synthesis_profile_id: "literature_review_v1",
      report_sections: sections,
      section_lookup: Map.new(sections, &{&1.id, &1}),
      resolved_records:
        sections
        |> Enum.with_index()
        |> Map.new(fn {_section, index} ->
          citation_key = "REC_000#{index + 1}"

          {citation_key,
           %{
             record_id: "record-#{index + 1}",
             classification: :accepted_core,
             citation_key: citation_key,
             title: "Record #{index + 1}",
             formula: %{status: :exact, exact_reusable_formula_texts: ["score = wins / total"]},
             provenance_reference: %{providers: [:serper]},
             scores: %{evidence_strength: 0.9}
           }}
        end),
      digest: "digest-1"
    }
  end

  defp formula_candidate_fixture do
    %FormulaCandidate{
      id: "formula-1",
      formula_text: "score = wins / total",
      exact?: true,
      partial?: false,
      blocked?: false,
      role: :calibration,
      source_section_ids: [:reusable_formulas],
      supporting_citation_keys: ["REC_0004"]
    }
  end

  defp required_section_ids do
    [
      :executive_summary,
      :ranked_important_papers_and_findings,
      :taxonomy_and_thematic_grouping,
      :reusable_formulas,
      :open_gaps,
      :next_prototype_recommendations
    ]
  end
end
