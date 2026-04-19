defmodule ResearchStore.CorpusRegistryTest do
  use ResearchStore.DataCase, async: true

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
  alias ResearchStore.{Branches, CorpusRegistry, Repo, RetrievalRegistry, Themes}
  alias ResearchStore.Artifacts.CorpusSnapshot
  alias ResearchStore.Artifacts.FetchedDocument, as: FetchedDocumentRecord
  alias ResearchStore.Artifacts.NormalizedRetrievalHit, as: RetrievalHitRecord
  alias ResearchStore.Artifacts.RetrievalRun, as: RetrievalRunRecord
  alias ResearchStore.Artifacts.SearchRequest, as: SearchRequestRecord

  test "stores the artifact chain, creates a snapshot, and exposes lineage queries" do
    %{normalized_theme: persisted_theme} = store_theme!()
    %{queries: queries} = store_branches!(persisted_theme.id)
    run = retrieval_run(queries)

    assert {:ok, %RetrievalRunRecord{id: "run-001"}} =
             RetrievalRegistry.store_run(run, normalized_theme_id: persisted_theme.id)

    assert {:ok, %RetrievalRunRecord{id: "run-001"}} =
             RetrievalRegistry.store_run(run, normalized_theme_id: persisted_theme.id)

    assert Repo.aggregate(RetrievalRunRecord, :count) == 1
    assert Repo.aggregate(SearchRequestRecord, :count) == 3
    assert Repo.aggregate(RetrievalHitRecord, :count) == 5
    assert Repo.aggregate(FetchedDocumentRecord, :count) == 4

    raw_records = raw_records(queries)
    qa_result = QA.process(raw_records)

    assert {:ok, %CorpusSnapshot{} = snapshot} =
             CorpusRegistry.create_snapshot(raw_records, qa_result,
               label: "prediction-market-calibration",
               normalized_theme_id: persisted_theme.id
             )

    assert length(CorpusRegistry.accepted_core_records(snapshot.id)) == 1
    assert length(CorpusRegistry.accepted_analog_records(snapshot.id)) == 1
    assert length(CorpusRegistry.background_records(snapshot.id)) == 1
    assert [%{reason_codes: [:missing_year]}] = CorpusRegistry.quarantine_records(snapshot.id)

    assert [%{canonical_record_id: canonical_record_id}] =
             CorpusRegistry.duplicate_groups(snapshot.id)

    snapshot_id = snapshot.id

    assert %CorpusSnapshot{id: ^snapshot_id} =
             CorpusRegistry.latest_snapshot_for_theme(persisted_theme.id)

    [direct_branch | _rest] = Branches.list_branches(persisted_theme.id)

    assert %CorpusSnapshot{id: ^snapshot_id} =
             CorpusRegistry.latest_snapshot_for_branch(direct_branch.id)

    assert {:ok, loaded} = CorpusRegistry.load_snapshot(snapshot.id)
    assert loaded.snapshot.id == snapshot.id
    assert length(loaded.accepted_core) == 1

    assert {:ok, provenance} = CorpusRegistry.provenance_summary(canonical_record_id)
    assert provenance.canonical_record.id == canonical_record_id
    assert length(provenance.raw_records) == 2
    assert length(provenance.retrieval_hits) == 2
    assert Enum.any?(provenance.snapshots, &(&1.id == snapshot.id))
  end

  test "fails loudly when QA artifacts reference retrieval lineage that was never persisted" do
    %{normalized_theme: persisted_theme} = store_theme!()
    %{queries: queries} = store_branches!(persisted_theme.id)

    raw_records = raw_records(queries)
    qa_result = QA.process(raw_records)

    assert {:error, {:missing_retrieval_hit, "raw-core-1"}} =
             CorpusRegistry.store_qa_artifacts(raw_records, qa_result,
               normalized_theme_id: persisted_theme.id
             )
  end

  test "prevents direct updates to finalized snapshots" do
    %{normalized_theme: persisted_theme} = store_theme!()
    %{queries: queries} = store_branches!(persisted_theme.id)
    run = retrieval_run(queries)

    assert {:ok, _run} = RetrievalRegistry.store_run(run, normalized_theme_id: persisted_theme.id)

    raw_records = raw_records(queries)
    qa_result = QA.process(raw_records)

    assert {:ok, %CorpusSnapshot{} = snapshot} =
             CorpusRegistry.create_snapshot(raw_records, qa_result,
               normalized_theme_id: persisted_theme.id
             )

    assert_raise Postgrex.Error, fn ->
      snapshot
      |> Ecto.Changeset.change(label: "mutated")
      |> Repo.update!()
    end
  end

  defp store_theme! do
    raw_theme = %Raw{raw_text: "prediction market calibration", source: "manual"}

    normalized_theme = %Normalized{
      original_input: raw_theme.raw_text,
      normalized_text: "prediction market calibration",
      topic: "prediction market calibration",
      notes: "Store coverage test"
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
      queries: %{
        direct: direct_query,
        analog: analog_query,
        method: method_query
      }
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
      query_families: [
        %QueryFamily{kind: :precision, rationale: "test family", queries: [query]}
      ]
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
