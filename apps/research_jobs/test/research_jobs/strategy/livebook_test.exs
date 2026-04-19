defmodule ResearchJobs.Strategy.LivebookTest do
  use ExUnit.Case, async: true

  alias ResearchJobs.Strategy.Livebook
  alias ResearchJobs.Strategy.LivebookFixtures
  alias ResearchJobs.Strategy.Providers.Fake

  test "fixture walkthrough helpers expose explicit step outputs for notebooks" do
    context = LivebookFixtures.context()
    package = Livebook.build_input_package!(context)

    formula_step =
      Livebook.run_formula_extraction!(package,
        provider: Fake,
        provider_opts: LivebookFixtures.fake_provider_opts()
      )

    assert [%{formula_text: "score = wins / total"} | _] = formula_step.raw_candidates

    formula_normalization =
      Livebook.normalize_formula_candidates(package, formula_step.raw_candidates)

    assert [%ResearchCore.Strategy.FormulaCandidate{exact?: true} | _] =
             formula_normalization.accepted

    strategy_step =
      Livebook.run_strategy_extraction!(
        package,
        formula_normalization.accepted,
        provider: Fake,
        provider_opts: LivebookFixtures.fake_provider_opts()
      )

    assert [%{title: "Calibration Gate"} | _] = strategy_step.raw_candidates

    normalized =
      Livebook.normalize!(
        package,
        formula_step.raw_candidates,
        strategy_step.raw_candidates
      )

    assert [%ResearchCore.Strategy.StrategySpec{readiness: :ready_for_backtest}] =
             normalized.specs

    assert Enum.any?(
             normalized.validation.rejected_candidates,
             &(&1.type == :unsupported_candidate)
           )
  end

  test "credential template exposes the notebook-configurable env surface" do
    template = Livebook.credential_template()

    assert Map.has_key?(template, :openai_api_key)
    assert Map.has_key?(template, :openai_api_url)
    assert Map.has_key?(template, :synthesis_llm_model)
    assert Map.has_key?(template, :strategy_llm_model)
    assert Map.has_key?(template, :serper_api_key)
    assert Map.has_key?(template, :jina_api_key)
  end
end
