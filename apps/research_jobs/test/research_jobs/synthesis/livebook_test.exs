defmodule ResearchJobs.Synthesis.LivebookTest do
  use ExUnit.Case, async: true

  alias ResearchJobs.Livebook.PipelineFixtures
  alias ResearchJobs.Synthesis.Livebook
  alias ResearchJobs.Synthesis.Providers.Fake
  alias ResearchJobs.Strategy.Livebook, as: StrategyLivebook

  test "notebook helpers build a validated synthesis context that feeds strategy extraction" do
    context = PipelineFixtures.context()

    package =
      Livebook.build_input_package!(
        context.bundle,
        "literature_review_v1",
        raw_records: context.raw_records,
        qa_result: context.qa_result
      )

    assert ["REC_0001", "REC_0002"] == Enum.map(package.citation_keys, & &1.key)

    assert [
             "We estimate calibration drift by regime and report score = wins / total as the operational metric."
           ] = hd(package.accepted_core).formula.exact_reusable_formula_texts

    request_spec = Livebook.build_request("literature_review_v1", package)

    assert "literature_review_v1" == request_spec.profile_id
    assert request_spec.prompt =~ "Use these sections exactly:"
    assert "Reusable Formulas" in request_spec.section_order

    assert {:ok, provider_response} =
             Livebook.run_provider(
               request_spec,
               provider: Fake,
               provider_opts: [content: PipelineFixtures.synthesis_markdown()]
             )

    validation = Livebook.validate("literature_review_v1", package, provider_response.content)
    assert validation.valid?

    synthesis_context =
      Livebook.build_context(
        context.bundle,
        "literature_review_v1",
        package,
        request_spec,
        provider_response,
        validation
      )

    assert {:ok, strategy_context} = Livebook.build_strategy_context(synthesis_context)

    strategy_package = StrategyLivebook.build_input_package!(strategy_context)

    assert Map.has_key?(strategy_package.resolved_records, "REC_0001")
    assert Enum.any?(strategy_package.report_sections, &(&1.id == :reusable_formulas))
  end
end
