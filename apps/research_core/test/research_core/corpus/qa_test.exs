defmodule ResearchCore.Corpus.QATest do
  use ExUnit.Case, async: true

  alias ResearchCore.Branch.{Branch, SearchQuery}
  alias ResearchCore.Corpus.{QA, RawRecord}
  alias ResearchCore.Retrieval.{FetchedDocument, NormalizedSearchHit}

  describe "canonicalize/1" do
    test "normalizes titles urls identifiers authors years and formula status" do
      raw_record =
        raw_record(
          "raw-canonical",
          "  [PDF] Learning Calibration  ",
          "https://Example.com/papers/calibration/?utm_source=test#section",
          citation: "Doe, Jane; Smith, John (2024). Learning Calibration. DOI:10.1234/ABC.45.",
          authors: "Doe, Jane; Smith, John",
          abstract:
            "Abstract\nLearning calibration improves decision quality across market settings.",
          methodology: "Randomized experiment across 4 cohorts.",
          findings: "Calibration improved Brier scores by 12%.",
          limitations: "The venue sample is small.",
          formula_text: "p = wins / total"
        )

      record = QA.canonicalize(raw_record)

      assert record.canonical_title == "Learning Calibration"
      assert record.canonical_url == "https://example.com/papers/calibration"
      assert record.identifiers.doi == "10.1234/abc.45"
      assert record.year == 2024
      assert record.authors == ["Doe, Jane", "Smith, John"]
      assert record.formula_completeness_status == :exact
      assert record.citation_quality_score >= 4
    end
  end

  describe "process/1 duplicate grouping" do
    test "groups exact duplicates by identifier and keeps merge provenance" do
      result =
        QA.process([
          core_record(
            "raw-dup-1",
            "Prediction Market Calibration Under Stress",
            "https://example.com/a"
          ),
          core_record(
            "raw-dup-2",
            "Prediction Market Calibration Under Stress",
            "https://mirror.example.com/a",
            citation:
              "Lee, Ada (2024). Prediction Market Calibration Under Stress. DOI:10.5555/CAL-1",
            authors: "Lee, Ada"
          )
        ])

      assert length(result.accepted_core) == 1
      assert [%{match_reasons: match_reasons}] = result.duplicate_groups
      assert Enum.any?(match_reasons, &(&1.rule == :exact_identifier))
      assert Enum.any?(result.decision_log, &(&1.action == :merged))
    end

    test "groups strong near-duplicate titles when year and token overlap line up" do
      result =
        QA.process([
          raw_record(
            "raw-near-1",
            "Prediction Market Calibration with Order Book Signals",
            "https://example.com/pm-calibration-1",
            citation: "Lee, Ada (2024). Prediction Market Calibration with Order Book Signals.",
            authors: "Lee, Ada",
            abstract: "Empirical calibration work using order book state signals.",
            methodology: "Field experiment across active markets.",
            findings: "Order book signals improved calibration accuracy.",
            limitations: "Venue sample remains small.",
            branch_kind: :direct,
            branch_label: "prediction market calibration"
          ),
          raw_record(
            "raw-near-2",
            "Order Book Signals for Prediction Market Calibration",
            "https://example.com/pm-calibration-2",
            citation: "Lee, Ada (2024). Order Book Signals for Prediction Market Calibration.",
            authors: "Lee, Ada",
            abstract: "Empirical calibration work using order book state signals.",
            methodology: "Field experiment across active markets.",
            findings: "Order book signals improved calibration accuracy.",
            limitations: "Venue sample remains small.",
            branch_kind: :direct,
            branch_label: "prediction market calibration"
          )
        ])

      assert length(result.duplicate_groups) == 1
      assert [%{match_reasons: match_reasons}] = result.duplicate_groups
      assert Enum.any?(match_reasons, &(&1.rule == :near_duplicate_title))
    end
  end

  describe "process/1 malformed and conflated records" do
    test "discards url-only pseudo citations with no usable metadata" do
      result =
        QA.process([
          raw_record(
            "raw-bad-url",
            "https://example.com/bad-source",
            "https://example.com/bad-source",
            citation: "https://example.com/bad-source"
          )
        ])

      assert [%{reason_codes: [:url_only_pseudo_citation]}] = result.discard_log
      assert result.quarantine == []
    end

    test "splits safely conflated records into candidate records" do
      conflated =
        raw_record(
          "raw-split",
          "Calibration Under Liquidity Stress; Forecast Accuracy Under Thin Markets",
          "https://example.com/conflated",
          citation:
            "Ng, Mira (2023). Calibration Under Liquidity Stress; Singh, Ravi (2022). Forecast Accuracy Under Thin Markets",
          abstract:
            "Empirical work on forecasting quality in thin markets with explicit methods, results, and limitations.",
          methodology: "Difference-in-differences with venue controls.",
          findings: "Forecast quality improves with calibrated market makers.",
          limitations: "Only two venues were observed."
        )

      result = QA.process([conflated])

      total_classified =
        length(result.accepted_core) + length(result.accepted_analog) + length(result.background)

      assert total_classified == 2

      assert Enum.any?(
               result.decision_log,
               &(&1.action == :split and &1.record_id == "raw-split")
             )
    end

    test "quarantines unsafe conflation that cannot be split reliably" do
      result =
        QA.process([
          raw_record(
            "raw-unsafe",
            "Merged citation record 2021 and 2023",
            "https://example.com/unsafe",
            citation: "Multiple papers DOI:10.1000/one and arXiv:2401.12345 in one blob",
            abstract: "This page blends multiple papers into one source blob.",
            methodology: "Methods are mixed.",
            findings: "Findings are mixed.",
            limitations: "Limitations are mixed."
          )
        ])

      assert [%{reason_codes: [:unsafe_conflation]}] = result.quarantine
    end

    test "quarantines otherwise usable records that are missing a year" do
      result =
        QA.process([
          raw_record(
            "raw-missing-year",
            "Forecast Calibration in Thin Markets",
            "https://example.com/no-year",
            authors: "Lee, Ada",
            abstract: "Useful empirical calibration study in thin markets.",
            methodology: "Panel regression across 12 weeks.",
            findings: "Calibration improves over baseline.",
            limitations: "Small sample."
          )
        ])

      assert [%{reason_codes: [:missing_year]}] = result.quarantine
    end
  end

  describe "process/1 classification and audit trail" do
    test "emits accepted core analog and background records with decision summaries" do
      result =
        QA.process([
          core_record(
            "raw-core",
            "Prediction Market Calibration Under Stress",
            "https://example.com/core"
          ),
          analog_record(
            "raw-analog",
            "Options Market Calibration for Thin Liquidity",
            "https://example.com/analog"
          ),
          docs_background_record(
            "raw-background",
            "Kalshi API Liquidity Rules",
            "https://docs.kalshi.com/liquidity"
          )
        ])

      assert length(result.accepted_core) == 1
      assert length(result.accepted_analog) == 1
      assert length(result.background) == 1
      assert result.qa_decision_summary.accepted_core == 1

      assert Enum.any?(
               result.decision_log,
               &(&1.action == :accepted and &1.classification == :accepted_core)
             )

      assert Enum.any?(
               result.decision_log,
               &(&1.action == :accepted and &1.classification == :accepted_analog)
             )

      assert Enum.any?(
               result.decision_log,
               &(&1.action == :downgraded and &1.classification == :background)
             )
    end

    test "is deterministic for the same input" do
      inputs = [
        core_record(
          "raw-det-1",
          "Prediction Market Calibration Under Stress",
          "https://example.com/deterministic-1"
        ),
        core_record(
          "raw-det-2",
          "Prediction Market Calibration Under Stress",
          "https://example.com/deterministic-2",
          citation:
            "Lee, Ada (2024). Prediction Market Calibration Under Stress. DOI:10.5555/CAL-1",
          authors: "Lee, Ada"
        ),
        raw_record(
          "raw-det-3",
          "https://example.com/bad-source",
          "https://example.com/bad-source",
          citation: "https://example.com/bad-source"
        )
      ]

      assert QA.process(inputs) == QA.process(inputs)
    end
  end

  defp core_record(id, title, url, overrides \\ []) do
    raw_record(
      id,
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
          formula_text: "score = wins / total",
          branch_kind: :direct,
          branch_label: "prediction market calibration"
        ],
        overrides
      )
    )
  end

  defp analog_record(id, title, url) do
    raw_record(id, title, url,
      citation: "Stone, Bea (2023). #{title}. SSRN 1234567",
      authors: "Stone, Bea",
      abstract: "Analog evidence from options markets with explicit empirical design.",
      methodology: "Event study across options venues.",
      findings: "Calibration discipline improves quote quality in analogous markets.",
      limitations: "Direct transfer to prediction markets is incomplete.",
      formula_text: "edge = payoff / variance",
      branch_kind: :analog,
      branch_label: "options market calibration analog"
    )
  end

  defp docs_background_record(id, title, url) do
    raw_record(id, title, url,
      citation: "Kalshi API Docs (2024). #{title}.",
      authors: "Kalshi",
      abstract: "Official documentation about venue-specific liquidity mechanics.",
      methodology: "Reference material for API requests and exchange rules.",
      findings: "Shows exact venue behavior, not cross-venue generality.",
      limitations: "Venue-specific and operational rather than empirical.",
      branch_kind: :method,
      branch_label: "prediction market calibration method"
    )
  end

  defp raw_record(id, title, url, overrides) do
    branch_kind = Keyword.get(overrides, :branch_kind, :direct)
    branch_label = Keyword.get(overrides, :branch_label, "prediction market calibration")

    %RawRecord{
      id: id,
      retrieval_run_id: "run-001",
      branch: %Branch{
        kind: branch_kind,
        label: branch_label,
        rationale: "test branch",
        theme_relation: "test"
      },
      search_hit: %NormalizedSearchHit{
        provider: :serper,
        query: %SearchQuery{
          text: branch_label,
          branch_kind: branch_kind,
          branch_label: branch_label
        },
        rank: 1,
        title: title,
        url: url,
        snippet: Keyword.get(overrides, :abstract)
      },
      fetched_document: fetched_document(url, title, overrides),
      raw_fields:
        overrides
        |> Enum.reject(fn {key, _value} -> key in [:branch_kind, :branch_label] end)
        |> Enum.into(%{})
    }
  end

  defp fetched_document(url, title, overrides) do
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
end
