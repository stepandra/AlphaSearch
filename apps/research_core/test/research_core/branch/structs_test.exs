defmodule ResearchCore.Branch.StructsTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Branch.BranchKind
  alias ResearchCore.Branch.QueryFamilyKind
  alias ResearchCore.Branch.SearchQuery
  alias ResearchCore.Branch.SourceFamily
  alias ResearchCore.Branch.SourceHint
  alias ResearchCore.Branch.QueryFamily
  alias ResearchCore.Branch.Branch

  # -------------------------------------------------------------------
  # BranchKind
  # -------------------------------------------------------------------

  describe "BranchKind" do
    test "all/0 returns exactly the six required kinds" do
      assert BranchKind.all() == [
               :direct,
               :narrower,
               :broader,
               :analog,
               :mechanism,
               :method
             ]
    end

    test "valid?/1 accepts each required kind" do
      for kind <- [:direct, :narrower, :broader, :analog, :mechanism, :method] do
        assert BranchKind.valid?(kind), "expected #{kind} to be valid"
      end
    end

    test "valid?/1 rejects unknown atoms" do
      refute BranchKind.valid?(:unknown)
      refute BranchKind.valid?(:crossover)
    end
  end

  # -------------------------------------------------------------------
  # QueryFamilyKind
  # -------------------------------------------------------------------

  describe "QueryFamilyKind" do
    test "all/0 returns exactly the six required kinds" do
      assert QueryFamilyKind.all() == [
               :precision,
               :recall,
               :synonym_alias,
               :literature_format,
               :venue_specific,
               :source_scoped
             ]
    end

    test "valid?/1 accepts each required kind" do
      for kind <-
            [
              :precision,
              :recall,
              :synonym_alias,
              :literature_format,
              :venue_specific,
              :source_scoped
            ] do
        assert QueryFamilyKind.valid?(kind), "expected #{kind} to be valid"
      end
    end

    test "valid?/1 rejects unknown atoms" do
      refute QueryFamilyKind.valid?(:unknown)
      refute QueryFamilyKind.valid?(:embedding)
    end
  end

  # -------------------------------------------------------------------
  # SourceFamily
  # -------------------------------------------------------------------

  describe "SourceFamily" do
    test "all/0 returns the supported preferred source families in canonical order" do
      assert SourceFamily.all() == [
               :academic_preprints,
               :econ_working_papers,
               :conference_proceedings,
               :official_docs,
               :official_sites,
               :code_repositories,
               :general_web
             ]
    end

    test "valid?/1 accepts each supported source family" do
      for family <- SourceFamily.all() do
        assert SourceFamily.valid?(family), "expected #{family} to be valid"
      end
    end

    test "valid?/1 rejects unknown families" do
      refute SourceFamily.valid?(:news_sites)
      refute SourceFamily.valid?(:social_media)
    end

    test "official_site_patterns/1 resolves known venue domains deterministically" do
      assert SourceFamily.official_site_patterns([
               "Kalshi exchange docs",
               "Polymarket API"
             ]) == ["site:kalshi.com", "site:polymarket.com"]

      assert SourceFamily.official_site_patterns("ambiguous topic") == []
    end
  end

  # -------------------------------------------------------------------
  # SourceHint
  # -------------------------------------------------------------------

  describe "SourceHint" do
    test "creates with required label" do
      hint = %SourceHint{label: "SSRN"}
      assert hint.label == "SSRN"
    end

    test "rejects creation without label via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(SourceHint, %{})
      end
    end

    test "pattern matches on label" do
      hint = %SourceHint{label: "arXiv"}
      assert %SourceHint{label: "arXiv"} = hint
    end
  end

  # -------------------------------------------------------------------
  # SearchQuery
  # -------------------------------------------------------------------

  describe "SearchQuery" do
    test "creates with required text and generic provenance defaults" do
      query = %SearchQuery{text: "prediction market calibration"}
      assert query.text == "prediction market calibration"
      assert query.source_hints == []
      assert query.scope_type == :generic
      assert query.source_family == nil
      assert query.scoped_pattern == nil
      assert query.branch_kind == nil
      assert query.branch_label == nil
    end

    test "creates with explicit scoped provenance" do
      query = %SearchQuery{
        text: "prediction market calibration",
        source_hints: [%SourceHint{label: "SSRN"}, %SourceHint{label: "arXiv"}],
        scope_type: :source_scoped,
        source_family: :academic_preprints,
        scoped_pattern: "site:arxiv.org",
        branch_kind: :direct,
        branch_label: "prediction market calibration"
      }

      assert query.text == "prediction market calibration"
      assert length(query.source_hints) == 2
      assert query.scope_type == :source_scoped
      assert query.source_family == :academic_preprints
      assert query.scoped_pattern == "site:arxiv.org"
      assert query.branch_kind == :direct
      assert query.branch_label == "prediction market calibration"
    end

    test "rejects creation without text via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(SearchQuery, %{source_hints: []})
      end
    end

    test "pattern matches on text" do
      query = %SearchQuery{text: "order book state"}
      assert %SearchQuery{text: "order book state"} = query
    end
  end

  # -------------------------------------------------------------------
  # QueryFamily
  # -------------------------------------------------------------------

  describe "QueryFamily" do
    test "creates with required fields, queries and source_families default to empty" do
      family = %QueryFamily{
        kind: :precision,
        rationale: "Targets exact topic terms"
      }

      assert family.kind == :precision
      assert family.rationale == "Targets exact topic terms"
      assert family.queries == []
      assert family.source_families == []
    end

    test "creates with all fields" do
      family = %QueryFamily{
        kind: :source_scoped,
        rationale: "Reserves scoped source targeting for later query expansion",
        source_families: [:academic_preprints, :conference_proceedings],
        queries: [
          %SearchQuery{
            text: "site:arxiv.org event market calibration",
            scope_type: :source_scoped,
            source_family: :academic_preprints,
            scoped_pattern: "site:arxiv.org",
            branch_kind: :direct,
            branch_label: "event market calibration"
          }
        ]
      }

      assert family.kind == :source_scoped
      assert family.source_families == [:academic_preprints, :conference_proceedings]
      assert length(family.queries) == 1
    end

    test "rejects creation without kind via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(QueryFamily, %{rationale: "some rationale"})
      end
    end

    test "rejects creation without rationale via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(QueryFamily, %{kind: :precision})
      end
    end

    test "pattern matches on kind and nested queries" do
      family = %QueryFamily{
        kind: :synonym_alias,
        rationale: "Alternative terminology",
        queries: [%SearchQuery{text: "event contract pricing"}]
      }

      assert %QueryFamily{
               kind: :synonym_alias,
               queries: [%SearchQuery{text: "event contract pricing"}]
             } = family
    end
  end

  # -------------------------------------------------------------------
  # Branch
  # -------------------------------------------------------------------

  describe "Branch" do
    test "creates with required fields and source-targeting defaults" do
      branch = %Branch{
        kind: :direct,
        label: "prediction market calibration with order-book state",
        rationale: "Direct expansion of the normalized theme",
        theme_relation: "Maps directly to the topic and mechanism hint"
      }

      assert branch.kind == :direct
      assert branch.label == "prediction market calibration with order-book state"
      assert branch.rationale == "Direct expansion of the normalized theme"
      assert branch.theme_relation == "Maps directly to the topic and mechanism hint"
      assert branch.query_families == []
      assert branch.preferred_source_families == []
      assert branch.source_targeting_rationale == nil
    end

    test "creates with all fields including query_families" do
      branch = %Branch{
        kind: :analog,
        label: "options skew calibration analogs",
        rationale: "Finds parallel calibration patterns in related markets",
        theme_relation: "Analog from prediction markets to options markets",
        preferred_source_families: [:econ_working_papers, :academic_preprints, :general_web],
        source_targeting_rationale:
          "Economics-oriented language biases the branch toward working-paper sources first",
        query_families: [
          %QueryFamily{
            kind: :precision,
            rationale: "Exact analog terms",
            queries: [%SearchQuery{text: "options skew calibration"}]
          }
        ]
      }

      assert branch.kind == :analog

      assert branch.preferred_source_families == [
               :econ_working_papers,
               :academic_preprints,
               :general_web
             ]

      assert is_binary(branch.source_targeting_rationale)
      assert length(branch.query_families) == 1
      assert [%QueryFamily{kind: :precision}] = branch.query_families
    end

    test "rejects creation without kind via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(Branch, %{
          label: "test",
          rationale: "test",
          theme_relation: "test"
        })
      end
    end

    test "rejects creation without label via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(Branch, %{
          kind: :direct,
          rationale: "test",
          theme_relation: "test"
        })
      end
    end

    test "rejects creation without rationale via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(Branch, %{
          kind: :direct,
          label: "test",
          theme_relation: "test"
        })
      end
    end

    test "rejects creation without theme_relation via struct!" do
      assert_raise ArgumentError, fn ->
        struct!(Branch, %{
          kind: :direct,
          label: "test",
          rationale: "test"
        })
      end
    end

    test "pattern matches on kind and nested query families" do
      branch = %Branch{
        kind: :mechanism,
        label: "order-book state as mispricing filter",
        rationale: "Focuses on the causal mechanism",
        theme_relation: "Extracts mechanism hint as primary lens",
        query_families: [
          %QueryFamily{
            kind: :literature_format,
            rationale: "Academic paper formats",
            queries: [
              %SearchQuery{
                text: "working paper order book mispricing",
                source_hints: [%SourceHint{label: "SSRN"}]
              }
            ]
          }
        ]
      }

      assert %Branch{
               kind: :mechanism,
               query_families: [
                 %QueryFamily{
                   kind: :literature_format,
                   queries: [
                     %SearchQuery{
                       text: "working paper order book mispricing",
                       source_hints: [%SourceHint{label: "SSRN"}]
                     }
                   ]
                 }
               ]
             } = branch
    end

    test "destructures Branch in function-head style" do
      branch = %Branch{
        kind: :narrower,
        label: "cheap OTM contract calibration",
        rationale: "Narrows scope to specific contract type",
        theme_relation: "Focuses on objective constraint",
        query_families: [
          %QueryFamily{kind: :recall, rationale: "Broad OTM terms", queries: []}
        ]
      }

      %Branch{kind: kind, query_families: [%QueryFamily{kind: fam_kind} | _]} = branch

      assert kind == :narrower
      assert fam_kind == :recall
    end
  end
end
