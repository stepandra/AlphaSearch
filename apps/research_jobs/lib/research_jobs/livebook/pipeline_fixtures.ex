defmodule ResearchJobs.Livebook.PipelineFixtures do
  @moduledoc """
  Deterministic fixture data for the full retrieval-to-strategy notebook walkthrough.
  """

  alias ResearchCore.Retrieval.{
    FetchRequest,
    FetchResult,
    FetchedDocument,
    NormalizedSearchHit,
    ProviderResult,
    RetrievalRun,
    SearchRequest
  }

  alias ResearchJobs.Livebook.Pipeline

  @fixture_timestamp ~U[2026-03-30 12:00:00Z]

  @spec theme_input() :: String.t()
  def theme_input do
    "prediction market calibration under stress"
  end

  @spec normalized_theme() :: ResearchCore.Theme.Normalized.t()
  def normalized_theme do
    Pipeline.normalize_theme!(theme_input())
  end

  @spec branches() :: [ResearchCore.Branch.Branch.t()]
  def branches do
    Pipeline.generate_branches(normalized_theme())
  end

  @spec query_rows() :: [map()]
  def query_rows do
    Pipeline.query_rows(branches())
  end

  @spec queries() :: %{direct: struct(), analog: struct(), method: struct()}
  def queries do
    %{
      direct: query_for!(:direct),
      analog: query_for!(:analog),
      method: query_for!(:method)
    }
  end

  @spec retrieval_run() :: RetrievalRun.t()
  def retrieval_run do
    %{direct: direct_query, analog: analog_query, method: method_query} = queries()

    direct_hits = [
      hit(
        :serper,
        direct_query,
        1,
        "Prediction Market Calibration Under Stress",
        "https://example.com/core-1",
        "Core study on calibration stability."
      )
    ]

    analog_hits = [
      hit(
        :serper,
        analog_query,
        1,
        "Options Market Calibration for Thin Liquidity",
        "https://example.com/analog-1",
        "Analog study on liquidity penalties."
      )
    ]

    method_hits = [
      hit(
        :serper,
        method_query,
        1,
        "Kalshi Liquidity Documentation",
        "https://docs.example.com/liquidity",
        "Venue-specific background documentation."
      )
    ]

    %RetrievalRun{
      id: "retrieval_fixture_001",
      started_at: @fixture_timestamp,
      completed_at: @fixture_timestamp,
      search_requests: [
        %SearchRequest{provider: :serper, query: direct_query, max_results: 5},
        %SearchRequest{provider: :serper, query: analog_query, max_results: 5},
        %SearchRequest{provider: :serper, query: method_query, max_results: 5}
      ],
      provider_results: [
        %ProviderResult{
          provider: :serper,
          request: %SearchRequest{provider: :serper, query: direct_query, max_results: 5},
          hits: direct_hits,
          raw_payload: %{"query" => direct_query.text}
        },
        %ProviderResult{
          provider: :serper,
          request: %SearchRequest{provider: :serper, query: analog_query, max_results: 5},
          hits: analog_hits,
          raw_payload: %{"query" => analog_query.text}
        },
        %ProviderResult{
          provider: :serper,
          request: %SearchRequest{provider: :serper, query: method_query, max_results: 5},
          hits: method_hits,
          raw_payload: %{"query" => method_query.text}
        }
      ],
      provider_errors: [],
      fetch_requests:
        Enum.map(direct_hits ++ analog_hits ++ method_hits, fn source_hit ->
          %FetchRequest{provider: :jina, url: source_hit.url, source_hit: source_hit}
        end),
      fetch_results:
        Enum.map(direct_hits ++ analog_hits ++ method_hits, fn source_hit ->
          %FetchResult{
            request: %FetchRequest{provider: :jina, url: source_hit.url, source_hit: source_hit},
            status: :ok,
            document: fetched_document(source_hit.url, source_hit.title)
          }
        end)
    }
  end

  @spec raw_records() :: [ResearchCore.Corpus.RawRecord.t()]
  def raw_records do
    Pipeline.build_raw_records(retrieval_run(), normalized_theme(), branches())
  end

  @spec qa_result() :: ResearchCore.Corpus.QAResult.t()
  def qa_result do
    Pipeline.run_qa(raw_records())
  end

  @spec bundle() :: map()
  def bundle do
    Pipeline.build_bundle(
      normalized_theme(),
      branches(),
      retrieval_run(),
      qa_result(),
      label: "prediction-market-calibration",
      snapshot_id: "snapshot_livebook_fixture",
      normalized_theme_id: "theme_livebook_fixture",
      finalized_at: @fixture_timestamp
    )
  end

  @spec synthesis_markdown() :: String.t()
  def synthesis_markdown do
    """
    ## Executive Summary
    Calibration remained stable under stress in the direct study [REC_0001], while liquidity frictions limited direct transfer from the analog evidence [REC_0002].

    ## Ranked Important Papers and Findings
    1. Prediction Market Calibration Under Stress [REC_0001]
    2. Options Market Calibration for Thin Liquidity [REC_0002]

    ## Taxonomy and Thematic Grouping
    Direct calibration evidence [REC_0001]. Transferability caution from analog options evidence [REC_0002].

    ## Reusable Formulas
    - score = wins / total [REC_0001]
    - No exact reusable formula was captured for liquidity transfer penalties [REC_0002]

    ## Open Gaps
    Venue-specific execution frictions remain insufficiently quantified [REC_0002].

    ## Next Prototype Recommendations
    Build a calibration gate around the direct score signal before introducing liquidity-aware penalties [REC_0001, REC_0002].

    ## Evidence Appendix
    - REC_0001 Prediction Market Calibration Under Stress
    - REC_0002 Options Market Calibration for Thin Liquidity
    """
  end

  @spec context() :: map()
  def context do
    %{
      theme_input: theme_input(),
      normalized_theme: normalized_theme(),
      branches: branches(),
      query_rows: query_rows(),
      queries: queries(),
      retrieval_run: retrieval_run(),
      raw_records: raw_records(),
      qa_result: qa_result(),
      bundle: bundle(),
      synthesis_markdown: synthesis_markdown()
    }
  end

  defp query_for!(branch_kind) do
    query_rows()
    |> Enum.find(&(&1.branch_kind == branch_kind))
    |> case do
      %{query: query} -> query
      nil -> raise ArgumentError, "missing fixture query for branch #{inspect(branch_kind)}"
    end
  end

  defp hit(provider, query, rank, title, url, snippet) do
    %NormalizedSearchHit{
      provider: provider,
      query: query,
      rank: rank,
      title: title,
      url: url,
      snippet: snippet,
      raw_payload: %{"title" => title, "url" => url}
    }
  end

  defp fetched_document("https://example.com/core-1", title) do
    %FetchedDocument{
      url: "https://example.com/core-1",
      title: title,
      content_format: :text,
      fetched_at: @fixture_timestamp,
      content: """
      Prediction Market Calibration Under Stress (2024)
      Authors: Alice Researcher

      Abstract
      We study calibration in stressed prediction markets across 12,000 contracts.

      Methodology
      We estimate calibration drift by regime and report score = wins / total as the operational metric.

      Results
      Calibration remains stable during volatility spikes when the score gate is respected.

      Limitations
      The study omits execution costs and does not fully test live deployment constraints.
      """
    }
  end

  defp fetched_document("https://example.com/analog-1", title) do
    %FetchedDocument{
      url: "https://example.com/analog-1",
      title: title,
      content_format: :text,
      fetched_at: @fixture_timestamp,
      content: """
      Options Market Calibration for Thin Liquidity (2022)
      Authors: Bob Researcher

      Abstract
      This analog study examines how calibration signals degrade under thin-liquidity execution.

      Methodology
      We compare calibration thresholds across liquidity regimes in options data.

      Results
      Liquidity penalties rise materially in thin markets.

      Limitations
      Transfer to prediction markets may be incomplete because venue microstructure differs.
      """
    }
  end

  defp fetched_document("https://docs.example.com/liquidity", title) do
    %FetchedDocument{
      url: "https://docs.example.com/liquidity",
      title: title,
      content_format: :text,
      fetched_at: @fixture_timestamp,
      content: """
      Kalshi Liquidity Documentation (2025)

      This documentation describes venue-specific quoting and liquidity rules for exchange operators.
      """
    }
  end
end
