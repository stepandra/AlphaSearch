defmodule ResearchCore.Branch.QueryFamilyGeneratorTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Branch.{
    Branch,
    QueryFamily,
    QueryFamilyGenerator,
    QueryFamilyKind,
    SearchQuery,
    SourceHint
  }

  alias ResearchCore.Theme.{Normalized, DomainHint, MechanismHint, Objective, Constraint}

  # -- Helpers --

  defp well_formed_theme do
    %Normalized{
      original_input: "raw input",
      normalized_text: "normalized input",
      topic: "prediction market calibration",
      domain_hints: [
        %DomainHint{label: "prediction markets"},
        %DomainHint{label: "options pricing"}
      ],
      mechanism_hints: [
        %MechanismHint{label: "order-book state"},
        %MechanismHint{label: "liquidity dynamics"}
      ],
      objective: %Objective{description: "cheap OTM contracts"},
      constraints: [%Constraint{description: "public data only", kind: :scope}]
    }
  end

  defp direct_branch do
    %Branch{
      kind: :direct,
      label: "prediction market calibration",
      rationale: "Direct exploration of the stated theme",
      theme_relation: "verbatim"
    }
  end

  defp analog_branch do
    %Branch{
      kind: :analog,
      label: "options pricing parallels to prediction market calibration",
      rationale: "Explores a parallel domain for transferable patterns and insights",
      theme_relation: "analogy"
    }
  end

  defp minimal_theme do
    %Normalized{
      original_input: "raw",
      normalized_text: "normalized",
      topic: "entropy"
    }
  end

  defp minimal_branch do
    %Branch{
      kind: :direct,
      label: "entropy",
      rationale: "Direct exploration of the stated theme",
      theme_relation: "verbatim"
    }
  end

  defp docs_first_theme do
    %Normalized{
      original_input: "public API docs for order routing integration",
      normalized_text: "public api docs for order routing integration",
      topic: "order routing",
      objective: %Objective{description: "public API docs"},
      domain_hints: [%DomainHint{label: "protocol integration"}],
      constraints: [%Constraint{description: "official documentation only", kind: :scope}]
    }
  end

  defp docs_first_branch do
    %Branch{
      kind: :direct,
      label: "order routing",
      rationale: "Direct exploration of the stated theme",
      theme_relation: "verbatim"
    }
  end

  defp academic_theme do
    %Normalized{
      original_input: "protocol incentive design paper",
      normalized_text: "protocol incentive design paper",
      topic: "protocol incentive design paper",
      objective: %Objective{description: "scholarly review"},
      notes: "research literature only"
    }
  end

  defp academic_branch do
    %Branch{
      kind: :direct,
      label: "protocol incentive design paper",
      rationale: "Direct exploration of the stated theme",
      theme_relation: "verbatim"
    }
  end

  # -- Core contract --

  describe "generate/2 with a well-formed theme and direct branch" do
    setup do
      %{families: QueryFamilyGenerator.generate(direct_branch(), well_formed_theme())}
    end

    test "returns exactly 6 families", %{families: families} do
      assert length(families) == 6
    end

    test "returns all family kinds in canonical order", %{families: families} do
      kinds = Enum.map(families, & &1.kind)
      assert kinds == QueryFamilyKind.all()
    end

    test "every family is a QueryFamily struct", %{families: families} do
      assert Enum.all?(families, &match?(%QueryFamily{}, &1))
    end

    test "every family has non-empty rationale", %{families: families} do
      for family <- families do
        assert is_binary(family.rationale) and family.rationale != ""
      end
    end

    test "every non-scoped family has at least one query", %{families: families} do
      for family <- families do
        expected_min = if family.kind == :source_scoped, do: 0, else: 1
        assert length(family.queries) >= expected_min
      end
    end

    test "every query is a SearchQuery with non-empty text", %{families: families} do
      for family <- families do
        for query <- family.queries do
          assert %SearchQuery{} = query
          assert is_binary(query.text) and query.text != ""
          assert query.branch_kind == :direct
          assert query.branch_label == "prediction market calibration"
        end
      end
    end
  end

  # -- Determinism --

  describe "determinism" do
    test "calling generate/2 twice on the same inputs produces identical output" do
      branch = direct_branch()
      theme = well_formed_theme()

      assert QueryFamilyGenerator.generate(branch, theme) ==
               QueryFamilyGenerator.generate(branch, theme)
    end

    test "deterministic across all branch kinds" do
      theme = well_formed_theme()

      for kind <- [:direct, :narrower, :broader, :analog, :mechanism, :method] do
        branch = %Branch{
          kind: kind,
          label: "test label for #{kind}",
          rationale: "test",
          theme_relation: "test"
        }

        assert QueryFamilyGenerator.generate(branch, theme) ==
                 QueryFamilyGenerator.generate(branch, theme),
               "Non-deterministic output for branch kind #{kind}"
      end
    end
  end

  # -- Individual family kinds --

  describe "precision family" do
    test "contains the branch label as a tight query" do
      families = QueryFamilyGenerator.generate(direct_branch(), well_formed_theme())
      precision = Enum.find(families, &(&1.kind == :precision))

      assert precision != nil
      assert length(precision.queries) >= 1

      texts = Enum.map(precision.queries, & &1.text)
      assert Enum.any?(texts, &(&1 =~ "prediction market calibration"))
    end
  end

  describe "recall family" do
    test "produces broader queries than precision" do
      families = QueryFamilyGenerator.generate(direct_branch(), well_formed_theme())
      recall = Enum.find(families, &(&1.kind == :recall))

      assert recall != nil
      assert length(recall.queries) >= 1
    end
  end

  describe "synonym_alias family" do
    test "includes alternative terminology when domain hints available" do
      families = QueryFamilyGenerator.generate(direct_branch(), well_formed_theme())
      synonym = Enum.find(families, &(&1.kind == :synonym_alias))

      assert synonym != nil
      assert length(synonym.queries) >= 1
    end
  end

  describe "literature_format family" do
    test "includes academic phrasing" do
      families = QueryFamilyGenerator.generate(direct_branch(), well_formed_theme())
      lit = Enum.find(families, &(&1.kind == :literature_format))

      assert lit != nil
      assert length(lit.queries) >= 1

      texts = Enum.map(lit.queries, & &1.text)

      assert Enum.any?(texts, fn t ->
               t =~ "paper" or t =~ "working paper" or t =~ "survey" or t =~ "review"
             end)
    end
  end

  describe "venue_specific family" do
    test "includes source hints when domain hints suggest venues" do
      families = QueryFamilyGenerator.generate(direct_branch(), well_formed_theme())
      venue = Enum.find(families, &(&1.kind == :venue_specific))

      assert venue != nil
      assert length(venue.queries) >= 1

      all_hints =
        venue.queries
        |> Enum.flat_map(& &1.source_hints)

      assert Enum.any?(all_hints, &match?(%SourceHint{}, &1))
    end
  end

  describe "source_scoped family" do
    test "stays empty when only general-web fallback exists" do
      families = QueryFamilyGenerator.generate(direct_branch(), well_formed_theme())
      source_scoped = Enum.find(families, &(&1.kind == :source_scoped))

      assert source_scoped != nil
      assert is_binary(source_scoped.rationale)
      assert source_scoped.queries == []
      assert is_list(source_scoped.source_families)
      assert :general_web in source_scoped.source_families
    end

    test "emits docs-first scoped queries for explicit source families" do
      families = QueryFamilyGenerator.generate(docs_first_branch(), docs_first_theme())
      source_scoped = Enum.find(families, &(&1.kind == :source_scoped))

      assert source_scoped.source_families == [
               :official_docs,
               :code_repositories,
               :official_sites,
               :general_web
             ]

      assert Enum.map(source_scoped.queries, & &1.scoped_pattern) == [
               "site:readthedocs.io",
               "site:docs.",
               "site:github.com"
             ]

      assert Enum.all?(source_scoped.queries, fn query ->
               query.scope_type == :source_scoped and
                 query.branch_kind == :direct and
                 query.branch_label == "order routing"
             end)
    end

    test "emits academic scoped queries for research-first themes" do
      families = QueryFamilyGenerator.generate(academic_branch(), academic_theme())
      source_scoped = Enum.find(families, &(&1.kind == :source_scoped))

      assert source_scoped.source_families == [
               :academic_preprints,
               :conference_proceedings,
               :general_web
             ]

      assert Enum.map(source_scoped.queries, & &1.scoped_pattern) == [
               "site:arxiv.org",
               "site:ssrn.com",
               "site:papers.ssrn.com",
               "site:osf.io",
               "site:openreview.net",
               "site:proceedings.mlr.press",
               "site:dl.acm.org"
             ]

      assert Enum.all?(source_scoped.queries, fn query ->
               String.starts_with?(query.text, query.scoped_pattern <> " ") and
                 query.source_family in [:academic_preprints, :conference_proceedings]
             end)
    end
  end

  # -- Analog branch --

  describe "generate/2 with analog branch" do
    test "produces families referencing the analog domain" do
      families = QueryFamilyGenerator.generate(analog_branch(), well_formed_theme())
      assert length(families) == 6

      all_texts =
        families
        |> Enum.flat_map(& &1.queries)
        |> Enum.map(& &1.text)

      assert Enum.any?(all_texts, &(&1 =~ "options pricing" or &1 =~ "prediction market"))
    end
  end

  # -- Minimal theme (fallbacks) --

  describe "generate/2 with minimal theme" do
    test "still produces 6 families with valid queries" do
      families = QueryFamilyGenerator.generate(minimal_branch(), minimal_theme())
      assert length(families) == 6

      for family <- families do
        expected_min = if family.kind == :source_scoped, do: 0, else: 1
        assert length(family.queries) >= expected_min

        for query <- family.queries do
          assert is_binary(query.text) and query.text != ""
        end
      end
    end

    test "venue_specific may have empty source_hints with minimal theme" do
      families = QueryFamilyGenerator.generate(minimal_branch(), minimal_theme())
      venue = Enum.find(families, &(&1.kind == :venue_specific))
      assert venue != nil
      # Still produces queries even without venue context
      assert length(venue.queries) >= 1
    end
  end

  # -- Edge cases --

  describe "edge cases" do
    test "handles branch with long label" do
      branch = %Branch{
        kind: :direct,
        label: String.duplicate("a", 500),
        rationale: "test",
        theme_relation: "test"
      }

      families = QueryFamilyGenerator.generate(branch, minimal_theme())
      assert length(families) == 6
    end

    test "handles branch with special characters in label" do
      branch = %Branch{
        kind: :direct,
        label: "topic with & symbols / slashes (parens)",
        rationale: "test",
        theme_relation: "test"
      }

      families = QueryFamilyGenerator.generate(branch, minimal_theme())
      assert length(families) == 6

      for family <- families do
        for query <- family.queries do
          assert is_binary(query.text)
        end
      end
    end

    test "normalizes whitespace-only topics into non-empty query text" do
      branch = %Branch{
        kind: :direct,
        label: "topic with & symbols / slashes (parens)",
        rationale: "test",
        theme_relation: "test"
      }

      theme = %Normalized{
        original_input: "raw",
        normalized_text: "normalized",
        topic: "   "
      }

      families = QueryFamilyGenerator.generate(branch, theme)
      assert length(families) == 6

      for family <- families do
        for query <- family.queries do
          assert query.text != ""
          assert query.text == String.trim(query.text)
          refute String.contains?(query.text, "  ")
        end
      end
    end
  end
end
