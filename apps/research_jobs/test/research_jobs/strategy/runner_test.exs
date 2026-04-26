defmodule ResearchJobs.Strategy.RunnerTest do
  use ExUnit.Case, async: false

  alias ResearchCore.Branch.{Branch, QueryFamily, SearchQuery}
  alias ResearchCore.Corpus.{QA, RawRecord}

  alias ResearchCore.Retrieval.{
    FetchRequest,
    FetchResult,
    FetchedDocument,
    NormalizedSearchHit,
    ProviderResult,
    RetrievalRun,
    SearchRequest
  }

  alias ResearchCore.Theme.{Normalized, Raw}
  alias ResearchJobs.Strategy.Runner
  alias ResearchJobs.Strategy.Providers.Fake
  alias ResearchStore.{Branches, CorpusRegistry, RetrievalRegistry, Themes}
  alias ResearchStore.Artifacts.CorpusSnapshot

  setup do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(ResearchStore.Repo, shared: false)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  test "runs strategy extraction end-to-end and persists ready specs" do
    snapshot = persisted_snapshot_fixture()
    assert {:ok, _synthesis_run} = persisted_synthesis_fixture(snapshot.id)

    assert {:ok, run} =
             Runner.run(snapshot.id, "literature_review_v1",
               provider: Fake,
               provider_opts: [
                 formula_content: formula_content(),
                 strategy_content: strategy_content()
               ]
             )

    assert run.state == :completed
    assert run.validation_result.valid?
    assert [%ResearchCore.Strategy.FormulaCandidate{}] = run.formulas

    assert [%ResearchCore.Strategy.StrategySpec{readiness: :ready_for_backtest}] =
             run.strategy_specs

    assert [%ResearchCore.Strategy.StrategySpec{readiness: :ready_for_backtest}] =
             ResearchStore.ready_strategy_specs_for_snapshot(snapshot.id)
  end

  test "marks the run validation_failed when strategies cite phantom evidence" do
    snapshot = persisted_snapshot_fixture()
    assert {:ok, _synthesis_run} = persisted_synthesis_fixture(snapshot.id)

    assert {:error, run} =
             Runner.run(snapshot.id, "literature_review_v1",
               provider: Fake,
               provider_opts: [
                 formula_content: formula_content(),
                 strategy_content:
                   update_in(
                     strategy_content(),
                     [:strategies, Access.at(0), :evidence_references],
                     fn _ ->
                       ["REC_9999"]
                     end
                   )
               ]
             )

    assert run.state == :validation_failed
    refute run.validation_result.valid?

    assert Enum.any?(
             run.validation_result.fatal_errors,
             &(&1.type == :unknown_citation_key and &1.severity == :fatal)
           )

    assert Enum.any?(
             run.validation_result.fatal_errors,
             &(&1.type == :no_accepted_strategy_specs and &1.severity == :fatal)
           )

    assert run.strategy_specs == []

    assert %ResearchCore.Strategy.ValidationResult{} =
             ResearchStore.strategy_validation_failures(run.id)
  end

  test "marks honest empty extraction results validation_failed instead of completing blank output" do
    snapshot = persisted_snapshot_fixture()
    assert {:ok, _synthesis_run} = persisted_synthesis_fixture(snapshot.id)

    assert {:error, run} =
             Runner.run(snapshot.id, "literature_review_v1",
               provider: Fake,
               provider_opts: [
                 formula_content: %{formulas: []},
                 strategy_content: %{strategies: []}
               ]
             )

    assert run.state == :validation_failed
    assert run.formulas == []
    assert run.strategy_specs == []
    assert Enum.any?(run.validation_result.fatal_errors, &(&1.type == :no_accepted_formulas))

    assert Enum.any?(
             run.validation_result.fatal_errors,
             &(&1.type == :no_accepted_strategy_specs)
           )
  end

  test "marks the run provider_failed when fake provider output fails schema validation" do
    snapshot = persisted_snapshot_fixture()
    assert {:ok, _synthesis_run} = persisted_synthesis_fixture(snapshot.id)

    assert {:error, run} =
             Runner.run(snapshot.id, "literature_review_v1",
               provider: Fake,
               provider_opts: [
                 formula_content: %{formulas: [%{role: :execution}]},
                 strategy_content: strategy_content()
               ]
             )

    assert run.state == :provider_failed
    assert run.provider_failure.reason == "invalid_fake_formula_output"
  end

  defp formula_content do
    %{
      formulas: [
        %{
          formula_text: "score = wins / total",
          exact: true,
          partial: false,
          blocked: false,
          role: :calibration,
          source_section_ids: ["reusable_formulas"],
          supporting_citation_keys: ["REC_0001"],
          symbol_glossary: %{"score" => "calibration score"},
          notes: ["exact"]
        }
      ]
    }
  end

  defp strategy_content do
    %{
      strategies: [
        %{
          title: "Calibration Gate",
          thesis: "Trade only when calibration exceeds the observed threshold.",
          category: :calibration_strategy,
          candidate_kind: :directly_specified_strategy,
          market_or_domain_applicability: "prediction markets",
          direct_signal_or_rule: "enter when score > 0.62",
          entry_condition: "score > 0.62",
          exit_condition: "score < 0.55",
          formula_references: ["__FIRST_FORMULA__"],
          required_features: [
            %{name: "score_feature", description: "formula output", status: :available}
          ],
          required_datasets: [
            %{name: "market_quotes", description: "market quotes", mapping_status: :mapped}
          ],
          execution_assumptions: [
            %{kind: :execution, description: "cross at midpoint", blocking?: false}
          ],
          sizing_assumptions: [%{kind: :sizing, description: "flat size", blocking?: false}],
          evidence_references: ["REC_0001"],
          evidence_pairs: [
            %{section_id: "executive_summary", citation_key: "REC_0001"}
          ],
          conflicting_or_cautionary_evidence: ["REC_0002"],
          conflicting_evidence_pairs: [
            %{section_id: "open_gaps", citation_key: "REC_0002"}
          ],
          conflict_note: "liquidity frictions may weaken transfer",
          expected_edge_source: "miscalibration",
          validation_hints: [%{kind: :holdout, description: "test by regime", priority: :high}],
          candidate_metrics: [%{name: "hit_rate", description: "win rate", direction: :maximize}],
          falsification_idea: "Randomizing calibration should erase the edge.",
          source_section_ids: ["executive_summary", "open_gaps"],
          notes: ["direct evidence"]
        }
      ]
    }
  end

  defp persisted_synthesis_fixture(snapshot_id) do
    ResearchJobs.Synthesis.Runner.run(snapshot_id, "literature_review_v1",
      provider: ResearchJobs.Synthesis.Providers.Fake,
      provider_opts: [content: valid_markdown()]
    )
  end

  defp valid_markdown do
    """
    ## Executive Summary
    Calibration improves under stress [REC_0001].

    ## Ranked Important Papers and Findings
    1. Prediction Market Calibration Under Stress [REC_0001]
    2. Options Market Calibration for Thin Liquidity [REC_0002]

    ## Taxonomy and Thematic Grouping
    Direct evidence [REC_0001]. Analog evidence [REC_0002]. Background context [REC_0003].

    ## Reusable Formulas
    - score = wins / total [REC_0001]
    - edge = payoff / variance [REC_0002]
    - Exact formula text unavailable [REC_0003]

    ## Open Gaps
    Cross-venue transfer remains underexplored [REC_0001, REC_0002].

    ## Next Prototype Recommendations
    Build a calibration review prototype [REC_0001].

    ## Evidence Appendix
    - REC_0001 Prediction Market Calibration Under Stress
    - REC_0002 Options Market Calibration for Thin Liquidity
    - REC_0003 Kalshi API Liquidity Rules
    """
  end

  defp persisted_snapshot_fixture do
    %{normalized_theme: persisted_theme} = store_theme!()
    %{queries: queries} = store_branches!(persisted_theme.id)
    run = retrieval_run(queries)

    assert {:ok, _run} = RetrievalRegistry.store_run(run, normalized_theme_id: persisted_theme.id)

    raw_records = raw_records(queries)
    qa_result = QA.process(raw_records)

    assert {:ok, %CorpusSnapshot{} = snapshot} =
             CorpusRegistry.create_snapshot(raw_records, qa_result,
               label: "prediction-market-calibration",
               normalized_theme_id: persisted_theme.id
             )

    snapshot
  end

  defp store_theme! do
    raw_theme = %Raw{raw_text: "prediction market calibration", source: "manual"}

    normalized_theme = %Normalized{
      original_input: raw_theme.raw_text,
      normalized_text: "prediction market calibration",
      topic: "prediction market calibration",
      notes: "Strategy runner test"
    }

    assert {:ok, persisted} = Themes.store_theme(raw_theme, normalized_theme)
    persisted
  end

  defp store_branches!(normalized_theme_id) do
    direct_query = query(:direct, "prediction market calibration")
    analog_query = query(:analog, "options market calibration analog")
    method_query = query(:method, "prediction market calibration method")

    branches = [
      branch(:direct, direct_query.branch_label, direct_query),
      branch(:analog, analog_query.branch_label, analog_query),
      branch(:method, method_query.branch_label, method_query)
    ]

    assert {:ok, _branches} = Branches.store_branches(normalized_theme_id, branches)

    %{
      queries: %{direct: direct_query, analog: analog_query, method: method_query}
    }
  end

  defp retrieval_run(queries) do
    direct_request = %SearchRequest{provider: :serper, query: queries.direct, max_results: 5}
    analog_request = %SearchRequest{provider: :serper, query: queries.analog, max_results: 5}
    method_request = %SearchRequest{provider: :serper, query: queries.method, max_results: 5}

    direct_hits = [
      hit(
        :serper,
        queries.direct,
        1,
        "Prediction Market Calibration Under Stress",
        "https://example.com/core-1",
        "Core study 1"
      ),
      hit(
        :serper,
        queries.direct,
        2,
        "Prediction Market Calibration Under Stress",
        "https://mirror.example.com/core-2",
        "Core study 2"
      ),
      hit(
        :serper,
        queries.direct,
        3,
        "Prediction Market Calibration Without Year",
        "https://example.com/quarantine",
        "Needs review"
      )
    ]

    analog_hits = [
      hit(
        :serper,
        queries.analog,
        1,
        "Options Market Calibration for Thin Liquidity",
        "https://example.com/analog",
        "Analog study"
      )
    ]

    method_hits = [
      hit(
        :serper,
        queries.method,
        1,
        "Kalshi API Liquidity Rules",
        "https://docs.kalshi.com/liquidity",
        "Docs record"
      )
    ]

    fetch_results =
      (direct_hits ++ analog_hits ++ method_hits)
      |> Enum.map(fn source_hit ->
        %FetchResult{
          request: %FetchRequest{provider: :jina, url: source_hit.url, source_hit: source_hit},
          status: :ok,
          document: fetched_document(source_hit.url, source_hit.title)
        }
      end)

    %RetrievalRun{
      id: "run-001",
      started_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      completed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      search_requests: [direct_request, analog_request, method_request],
      provider_results: [
        %ProviderResult{
          provider: :serper,
          request: direct_request,
          hits: direct_hits,
          raw_payload: %{}
        },
        %ProviderResult{
          provider: :serper,
          request: analog_request,
          hits: analog_hits,
          raw_payload: %{}
        },
        %ProviderResult{
          provider: :serper,
          request: method_request,
          hits: method_hits,
          raw_payload: %{}
        }
      ],
      provider_errors: [],
      fetch_requests: Enum.map(fetch_results, & &1.request),
      fetch_results: fetch_results
    }
  end

  defp raw_records(queries) do
    [
      core_record(
        "raw-core-1",
        queries.direct,
        "Prediction Market Calibration Under Stress",
        "https://example.com/core-1"
      ),
      core_record(
        "raw-core-2",
        queries.direct,
        "Prediction Market Calibration Under Stress",
        "https://mirror.example.com/core-2",
        citation:
          "Lee, Ada (2024). Prediction Market Calibration Under Stress. DOI:10.5555/CAL-1",
        authors: "Lee, Ada"
      ),
      analog_record(
        "raw-analog",
        queries.analog,
        "Options Market Calibration for Thin Liquidity",
        "https://example.com/analog"
      ),
      docs_background_record(
        "raw-background",
        queries.method,
        "Kalshi API Liquidity Rules",
        "https://docs.kalshi.com/liquidity"
      ),
      missing_year_record(
        "raw-quarantine",
        queries.direct,
        "Prediction Market Calibration Without Year",
        "https://example.com/quarantine"
      )
    ]
  end

  defp branch(kind, label, query) do
    %Branch{
      kind: kind,
      label: label,
      rationale: "test branch",
      theme_relation: "test relation",
      query_families: [%QueryFamily{kind: :precision, rationale: "test family", queries: [query]}]
    }
  end

  defp query(branch_kind, branch_label) do
    %SearchQuery{text: branch_label, branch_kind: branch_kind, branch_label: branch_label}
  end

  defp core_record(id, query, title, url, overrides \\ []) do
    raw_record(
      id,
      query,
      title,
      url,
      Keyword.merge(
        [
          citation: "Lee, Ada (2024). #{title}. DOI:10.5555/CAL-1",
          authors: "Lee, Ada",
          abstract: "Empirical analysis of prediction market calibration under venue stress.",
          methodology: "Randomized controlled experiment with 1,200 observations.",
          findings: "Calibration improved Brier scores and reduced spread noise.",
          limitations: "Only three venues are observed.",
          formula_text: "score = wins / total"
        ],
        overrides
      )
    )
  end

  defp analog_record(id, query, title, url) do
    raw_record(id, query, title, url,
      citation: "Stone, Bea (2023). #{title}. SSRN 1234567",
      authors: "Stone, Bea",
      abstract: "Analog evidence from options markets with explicit empirical design.",
      methodology: "Event study across options venues.",
      findings: "Calibration discipline improves quote quality in analogous markets.",
      limitations: "Direct transfer to prediction markets is incomplete.",
      formula_text: "edge = payoff / variance"
    )
  end

  defp docs_background_record(id, query, title, url) do
    raw_record(id, query, title, url,
      citation: "Kalshi API Docs (2024). #{title}.",
      authors: "Kalshi",
      abstract: "Official documentation about venue-specific liquidity mechanics.",
      methodology: "Reference material for API requests and exchange rules.",
      findings: "Shows exact venue behavior, not cross-venue generality.",
      limitations: "Venue-specific and operational rather than empirical."
    )
  end

  defp missing_year_record(id, query, title, url) do
    raw_record(id, query, title, url,
      citation: "Lee, Ada. #{title}.",
      authors: "Lee, Ada",
      abstract: "Empirical analysis of prediction market calibration under venue stress.",
      methodology: "Randomized controlled experiment with 1,200 observations.",
      findings: "Calibration improved Brier scores and reduced spread noise.",
      limitations: "Only three venues are observed.",
      formula_text: "score = wins / total"
    )
  end

  defp raw_record(id, query, title, url, overrides) do
    %RawRecord{
      id: id,
      retrieval_run_id: "run-001",
      branch: %Branch{
        kind: query.branch_kind,
        label: query.branch_label,
        rationale: "test branch",
        theme_relation: "test"
      },
      search_hit:
        hit(:serper, query, rank_for_url(url), title, url, Keyword.get(overrides, :abstract)),
      fetched_document: fetched_document(url, title, overrides),
      raw_fields: Map.new(overrides)
    }
  end

  defp hit(provider, query, rank, title, url, snippet) do
    %NormalizedSearchHit{
      provider: provider,
      query: query,
      rank: rank,
      title: title,
      url: url,
      snippet: snippet,
      fetch_status: :ok
    }
  end

  defp fetched_document(url, title, overrides \\ []) do
    content =
      [
        "# #{title}",
        Keyword.get(overrides, :abstract),
        "## Methodology",
        Keyword.get(overrides, :methodology),
        "## Findings",
        Keyword.get(overrides, :findings),
        "## Limitations",
        Keyword.get(overrides, :limitations)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")

    %FetchedDocument{url: url, title: title, content: content, content_format: :markdown}
  end

  defp rank_for_url("https://example.com/core-1"), do: 1
  defp rank_for_url("https://mirror.example.com/core-2"), do: 2
  defp rank_for_url("https://example.com/quarantine"), do: 3
  defp rank_for_url(_url), do: 1
end
