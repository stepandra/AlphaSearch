defmodule ResearchCore.Corpus.StructsTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Branch.SearchQuery

  alias ResearchCore.Corpus.{
    AcceptanceDecision,
    CanonicalRecord,
    DuplicateGroup,
    FormulaCompletenessStatus,
    QAResult,
    QuarantineRecord,
    RawRecord,
    RecordClassification,
    RejectionReason,
    SourceIdentifiers,
    SourceProvenanceSummary
  }

  alias ResearchCore.Retrieval.NormalizedSearchHit

  describe "RecordClassification" do
    test "all/0 returns the supported output buckets in canonical order" do
      assert RecordClassification.all() == [
               :accepted_core,
               :accepted_analog,
               :background,
               :quarantine,
               :discard
             ]
    end

    test "valid?/1 accepts known classifications and rejects unknown ones" do
      assert RecordClassification.valid?(:accepted_core)
      assert RecordClassification.valid?(:background)
      refute RecordClassification.valid?(:merged)
    end
  end

  describe "FormulaCompletenessStatus" do
    test "all/0 returns the supported formula states" do
      assert FormulaCompletenessStatus.all() == [
               :exact,
               :partial,
               :referenced_only,
               :none,
               :unknown
             ]
    end
  end

  describe "RejectionReason" do
    test "contains the hard-fail and downgrade reasons used by QA" do
      assert RejectionReason.valid?(:url_only_pseudo_citation)
      assert RejectionReason.valid?(:missing_year)
      assert RejectionReason.valid?(:unsafe_conflation)
      refute RejectionReason.valid?(:strong_core_evidence)
    end
  end

  describe "SourceIdentifiers" do
    test "counts only present identifiers" do
      identifiers = %SourceIdentifiers{doi: "10.1000/xyz", url: "https://example.com"}

      assert SourceIdentifiers.count(identifiers) == 2
      refute SourceIdentifiers.blank?(identifiers)
    end
  end

  describe "RawRecord" do
    test "keeps search provenance with explicit defaults" do
      raw_record = %RawRecord{
        id: "raw-1",
        search_hit: %NormalizedSearchHit{
          provider: :serper,
          query: %SearchQuery{text: "prediction market calibration"},
          rank: 1,
          title: "Calibration in prediction markets",
          url: "https://example.com/calibration"
        }
      }

      assert raw_record.raw_fields == %{}
      assert raw_record.fetched_document == nil
      assert raw_record.split_from_id == nil
    end
  end

  describe "CanonicalRecord" do
    test "stores normalized fields provenance and QA decisions" do
      record = %CanonicalRecord{
        id: "canonical-1",
        canonical_title: "Calibration in prediction markets",
        identifiers: %SourceIdentifiers{doi: "10.1000/xyz"},
        formula_completeness_status: :partial,
        source_provenance_summary: %SourceProvenanceSummary{
          providers: [:serper],
          raw_record_ids: ["raw-1"]
        },
        normalized_fields: %{canonical_title: "Calibration in prediction markets"},
        qa_decisions: [
          %AcceptanceDecision{record_id: "canonical-1", stage: :classification, action: :accepted}
        ]
      }

      assert record.classification == nil
      assert record.normalized_fields.canonical_title == "Calibration in prediction markets"
      assert [%AcceptanceDecision{action: :accepted}] = record.qa_decisions
    end
  end

  describe "DuplicateGroup and QuarantineRecord" do
    test "retain merge and quarantine audit details" do
      decision = %AcceptanceDecision{
        record_id: "canonical-2",
        canonical_record_id: "canonical-1",
        stage: :duplicate_grouping,
        action: :merged,
        duplicate_group_id: "dup-1"
      }

      duplicate_group = %DuplicateGroup{
        id: "dup-1",
        canonical_record_id: "canonical-1",
        representative_record_id: "canonical-1",
        member_record_ids: ["canonical-1", "canonical-2"],
        member_raw_record_ids: ["raw-1", "raw-2"],
        match_reasons: [%{rule: :exact_identifier, identifier: :doi, value: "10.1000/xyz"}],
        decisions: [decision]
      }

      quarantine = %QuarantineRecord{
        id: "quarantine:raw-3",
        raw_record_ids: ["raw-3"],
        reason_codes: [:unsafe_conflation],
        decision: %AcceptanceDecision{
          record_id: "raw-3",
          stage: :conflation_detection,
          action: :quarantined,
          classification: :quarantine,
          reason_codes: [:unsafe_conflation]
        }
      }

      result = %QAResult{duplicate_groups: [duplicate_group], quarantine: [quarantine]}

      assert [%DuplicateGroup{id: "dup-1"}] = result.duplicate_groups
      assert [%QuarantineRecord{id: "quarantine:raw-3"}] = result.quarantine
    end
  end
end
