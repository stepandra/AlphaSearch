defmodule ResearchCore.Branch.DuplicateSuppressionTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Branch.{DuplicateSuppression, SearchQuery, SourceHint}

  defp query(text, source_hints \\ []) do
    %SearchQuery{text: text, source_hints: source_hints}
  end

  describe "deduplicate/1" do
    test "removes exact duplicate queries while preserving encounter order" do
      queries = [
        query("prediction market calibration"),
        query("prediction market calibration"),
        query("order book state")
      ]

      assert DuplicateSuppression.deduplicate(queries) == [
               query("prediction market calibration"),
               query("order book state")
             ]
    end

    test "removes whitespace-normalized duplicates" do
      queries = [
        query("prediction market calibration"),
        query("  prediction   market   calibration  ")
      ]

      assert DuplicateSuppression.deduplicate(queries) == [
               query("prediction market calibration")
             ]
    end

    test "removes case-only duplicates" do
      queries = [
        query("Prediction Market Calibration"),
        query("prediction market calibration")
      ]

      assert DuplicateSuppression.deduplicate(queries) == [
               query("Prediction Market Calibration")
             ]
    end

    test "removes simple near duplicates based on sorted tokens" do
      queries = [
        query("\"prediction market calibration\" working paper"),
        query("working paper prediction-market calibration")
      ]

      assert DuplicateSuppression.deduplicate(queries) == [
               query("\"prediction market calibration\" working paper")
             ]
    end

    test "merges unique source hints from suppressed duplicates" do
      queries = [
        query("Kalshi calibration", [%SourceHint{label: "Kalshi"}]),
        query("kalshi calibration", [%SourceHint{label: "SSRN"}]),
        query("kalshi calibration", [%SourceHint{label: "kalshi"}])
      ]

      assert DuplicateSuppression.deduplicate(queries) == [
               query("Kalshi calibration", [
                 %SourceHint{label: "Kalshi"},
                 %SourceHint{label: "SSRN"}
               ])
             ]
    end

    test "preserves genuinely distinct queries" do
      queries = [
        query("prediction market calibration"),
        query("prediction market liquidity"),
        query("survey review prediction market calibration")
      ]

      assert DuplicateSuppression.deduplicate(queries) == queries
    end

    test "is idempotent for mixed duplicate inputs" do
      queries = [
        query("prediction market calibration", [%SourceHint{label: "SSRN"}]),
        query("Prediction Market Calibration", [%SourceHint{label: "NBER"}]),
        query("working paper prediction market calibration"),
        query("\"prediction market calibration\" working paper")
      ]

      deduplicated = DuplicateSuppression.deduplicate(queries)

      assert DuplicateSuppression.deduplicate(deduplicated) == deduplicated
    end
  end
end
