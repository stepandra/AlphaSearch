defmodule ResearchCore.Branch.SearchPlanGeneratorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ResearchCore.Branch.{
    Branch,
    BranchKind,
    DuplicateSuppression,
    QueryFamilyKind,
    SearchPlanGenerator
  }

  alias ResearchCore.Theme.{Constraint, DomainHint, MechanismHint, Normalized, Objective}

  describe "generate/1" do
    test "returns fully populated branches for a prediction-market theme" do
      branches = SearchPlanGenerator.generate(prediction_market_theme())

      assert Enum.map(branches, & &1.kind) == BranchKind.all()

      for %Branch{query_families: query_families} <- branches do
        assert Enum.map(query_families, & &1.kind) == QueryFamilyKind.all()
        assert is_list(query_families)
      end

      for %Branch{preferred_source_families: preferred_source_families} <- branches do
        assert preferred_source_families != []
        assert :general_web in preferred_source_families
      end

      for %Branch{source_targeting_rationale: source_targeting_rationale} <- branches do
        assert is_binary(source_targeting_rationale)
        assert source_targeting_rationale != ""
      end

      for %Branch{query_families: query_families} <- branches do
        for family <- query_families do
          expected_min = if family.kind == :source_scoped, do: 0, else: 1
          assert length(family.queries) >= expected_min
          assert DuplicateSuppression.deduplicate(family.queries) == family.queries

          for query <- family.queries do
            assert is_binary(query.text)
            assert query.text != ""
            assert query.text == String.trim(query.text)
            refute String.contains?(query.text, "  ")
          end
        end
      end

      direct = Enum.find(branches, &(&1.kind == :direct))
      assert direct.label == "prediction market calibration"

      venue_specific =
        Enum.find(direct.query_families, &(&1.kind == :venue_specific))

      source_labels =
        venue_specific.queries
        |> Enum.flat_map(& &1.source_hints)
        |> Enum.map(& &1.label)

      assert "Kalshi" in source_labels
      assert "Polymarket" in source_labels

      source_scoped =
        Enum.find(direct.query_families, &(&1.kind == :source_scoped))

      assert source_scoped.source_families == direct.preferred_source_families
      assert source_scoped.queries == []

      analog = Enum.find(branches, &(&1.kind == :analog))
      assert analog.label =~ "options pricing"

      method = Enum.find(branches, &(&1.kind == :method))
      assert method.label =~ "liquidity covariates"
    end

    test "keeps ambiguous themes inspectable across all branches" do
      branches = SearchPlanGenerator.generate(ambiguous_theme())

      assert length(branches) == 6

      broader = Enum.find(branches, &(&1.kind == :broader))
      assert broader.label =~ "prediction markets"
      assert broader.label =~ "market calibration"

      analog = Enum.find(branches, &(&1.kind == :analog))
      assert analog.label =~ "sports betting"

      mechanism = Enum.find(branches, &(&1.kind == :mechanism))

      mechanism_texts =
        mechanism.query_families
        |> Enum.flat_map(& &1.queries)
        |> Enum.map(& &1.text)

      assert Enum.any?(mechanism_texts, &String.contains?(&1, "liquidity conditions"))
    end

    test "carries docs-first source preferences onto neutral direct branches" do
      branches = SearchPlanGenerator.generate(docs_first_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))
      source_scoped = Enum.find(direct.query_families, &(&1.kind == :source_scoped))

      assert direct.preferred_source_families == [
               :official_docs,
               :code_repositories,
               :official_sites,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "documentation"

      assert Enum.map(source_scoped.queries, & &1.scoped_pattern) == [
               "site:readthedocs.io",
               "site:docs.",
               "site:github.com"
             ]
    end

    test "keeps exchange docs fee schedule branches official-site first" do
      branches = SearchPlanGenerator.generate(exchange_docs_fee_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.preferred_source_families == [
               :official_sites,
               :official_docs,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "venue"
    end

    test "keeps plain exchange docs branches official-site first" do
      branches = SearchPlanGenerator.generate(plain_exchange_docs_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.preferred_source_families == [
               :official_sites,
               :official_docs,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "official sites"
    end

    test "keeps neutral docs-first themes docs-first when notes mention behavior" do
      branches = SearchPlanGenerator.generate(docs_first_behavior_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.preferred_source_families == [
               :official_docs,
               :code_repositories,
               :official_sites,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "documentation"
    end

    test "keeps docs-first themes docs-first when domain hints include component names" do
      branches = SearchPlanGenerator.generate(docs_first_component_name_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.preferred_source_families == [
               :official_docs,
               :code_repositories,
               :official_sites,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "documentation"
    end

    test "keeps docs-first themes docs-first when domain hints include docs component labels" do
      branches = SearchPlanGenerator.generate(docs_first_documentation_component_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.preferred_source_families == [
               :official_docs,
               :code_repositories,
               :official_sites,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "documentation"
    end

    test "keeps docs-first themes docs-first when domain hints include abbreviated docs component labels" do
      branches = SearchPlanGenerator.generate(docs_first_abbreviated_docs_component_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.preferred_source_families == [
               :official_docs,
               :code_repositories,
               :official_sites,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "documentation"
    end

    test "keeps docs-first themes docs-first when domain hints include page-oriented docs component labels" do
      branches = SearchPlanGenerator.generate(docs_first_page_component_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.preferred_source_families == [
               :official_docs,
               :code_repositories,
               :official_sites,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "documentation"
    end

    test "keeps docs-first themes docs-first when direct theme text includes page-oriented docs component labels" do
      branches = SearchPlanGenerator.generate(direct_theme_text_page_component_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.label == "exchange docs page renderer"

      assert direct.preferred_source_families == [
               :official_docs,
               :code_repositories,
               :official_sites,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "documentation"
    end

    test "keeps docs-first themes docs-first when direct theme text ends with a page-oriented venue phrase" do
      branches = SearchPlanGenerator.generate(suffix_theme_text_page_component_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.label == "renderer for exchange docs page"

      assert direct.preferred_source_families == [
               :official_docs,
               :code_repositories,
               :official_sites,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "documentation"
    end

    test "keeps scholarly protocol-paper themes academic-first" do
      branches = SearchPlanGenerator.generate(protocol_paper_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))
      source_scoped = Enum.find(direct.query_families, &(&1.kind == :source_scoped))

      assert direct.label == "protocol incentive design paper"

      assert direct.preferred_source_families == [
               :academic_preprints,
               :conference_proceedings,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "research"

      assert Enum.map(source_scoped.queries, & &1.scoped_pattern) == [
               "site:arxiv.org",
               "site:ssrn.com",
               "site:papers.ssrn.com",
               "site:osf.io",
               "site:openreview.net",
               "site:proceedings.mlr.press",
               "site:dl.acm.org"
             ]
    end

    test "keeps scholarly themes with generic docs words academic-first" do
      for theme <- [
            implementation_survey_paper_theme(),
            integration_incentive_design_paper_theme()
          ] do
        branches = SearchPlanGenerator.generate(theme)
        direct = Enum.find(branches, &(&1.kind == :direct))

        assert direct.label == theme.topic

        assert direct.preferred_source_families == [
                 :academic_preprints,
                 :conference_proceedings,
                 :general_web
               ]

        assert String.downcase(direct.source_targeting_rationale) =~ "research"
      end
    end

    test "keeps scholarly themes with strong docs keywords academic-first" do
      branches = SearchPlanGenerator.generate(api_usage_survey_paper_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.label == "api usage survey paper"

      assert direct.preferred_source_families == [
               :academic_preprints,
               :conference_proceedings,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "research"
    end

    test "keeps ML benchmark themes academic-first even when they include docs keywords" do
      branches = SearchPlanGenerator.generate(transformer_api_benchmarks_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.label == "transformer api benchmarks"

      assert direct.preferred_source_families == [
               :academic_preprints,
               :conference_proceedings,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "machine"
    end

    test "keeps clear ML themes academic-first when api is the only docs keyword" do
      branches = SearchPlanGenerator.generate(transformer_api_alignment_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      assert direct.label == "transformer api alignment"

      assert direct.preferred_source_families == [
               :academic_preprints,
               :conference_proceedings,
               :general_web
             ]

      assert String.downcase(direct.source_targeting_rationale) =~ "machine"
    end

    test "keeps clear ML themes academic-first even with strong docs keywords" do
      for {theme, label} <- [
            {transformer_docs_alignment_theme(), "transformer docs alignment"},
            {transformer_sdk_alignment_theme(), "transformer sdk alignment"}
          ] do
        branches = SearchPlanGenerator.generate(theme)
        direct = Enum.find(branches, &(&1.kind == :direct))

        assert direct.label == label

        assert direct.preferred_source_families == [
                 :academic_preprints,
                 :conference_proceedings,
                 :general_web
               ]

        assert String.downcase(direct.source_targeting_rationale) =~ "machine"
      end
    end

    test "keeps clear ML abbreviation themes academic-first even with strong docs keywords" do
      for {theme, label} <- [
            {ai_docs_alignment_theme(), "ai docs alignment"},
            {ml_sdk_alignment_theme(), "ml sdk alignment"}
          ] do
        branches = SearchPlanGenerator.generate(theme)
        direct = Enum.find(branches, &(&1.kind == :direct))

        assert direct.label == label

        assert direct.preferred_source_families == [
                 :academic_preprints,
                 :conference_proceedings,
                 :general_web
               ]

        assert String.downcase(direct.source_targeting_rationale) =~ "machine"
      end
    end

    test "suppresses generated duplicates within each query family" do
      branches = SearchPlanGenerator.generate(duplicate_friendly_theme())
      direct = Enum.find(branches, &(&1.kind == :direct))

      precision = Enum.find(direct.query_families, &(&1.kind == :precision))

      assert Enum.map(precision.queries, & &1.text) == ["prediction market calibration"]
    end

    property "is deterministic for arbitrary normalized themes" do
      check all(theme <- normalized_theme_generator()) do
        assert SearchPlanGenerator.generate(theme) == SearchPlanGenerator.generate(theme)
      end
    end
  end

  defp prediction_market_theme do
    %Normalized{
      original_input:
        "prediction market calibration using order book state for cheap OTM contracts",
      normalized_text: "prediction market calibration order book state cheap OTM contracts",
      topic: "prediction market calibration",
      domain_hints: [
        %DomainHint{label: "prediction markets"},
        %DomainHint{label: "options pricing"}
      ],
      mechanism_hints: [
        %MechanismHint{label: "order-book state"},
        %MechanismHint{label: "liquidity covariates"}
      ],
      objective: %Objective{description: "cheap OTM contracts"},
      constraints: [%Constraint{description: "public data only", kind: :scope}],
      notes: "focus on inspectable calibration workflows"
    }
  end

  defp ambiguous_theme do
    %Normalized{
      original_input: "market calibration in thin venues with noisy incentives",
      normalized_text: "market calibration thin venues noisy incentives",
      topic: "market calibration",
      domain_hints: [
        %DomainHint{label: "prediction markets"},
        %DomainHint{label: "sports betting"}
      ],
      mechanism_hints: [%MechanismHint{label: "liquidity conditions"}],
      objective: %Objective{description: "separate noise from miscalibration"},
      constraints: [%Constraint{description: "public data only", kind: :scope}],
      notes: "could refer to pricing efficiency or forecast accuracy"
    }
  end

  defp duplicate_friendly_theme do
    %Normalized{
      original_input: "prediction market calibration",
      normalized_text: "prediction market calibration",
      topic: "prediction market calibration",
      objective: %Objective{description: "   "}
    }
  end

  defp docs_first_theme do
    %Normalized{
      original_input: "public API docs for order routing integration",
      normalized_text: "public api docs for order routing integration",
      topic: "order routing",
      domain_hints: [%DomainHint{label: "protocol integration"}],
      objective: %Objective{description: "public API docs"},
      constraints: [%Constraint{description: "official documentation only", kind: :scope}],
      notes: "prefer public docs over commentary"
    }
  end

  defp exchange_docs_fee_theme do
    %Normalized{
      original_input: "exchange docs fee schedule",
      normalized_text: "exchange docs fee schedule",
      topic: "exchange docs fee schedule",
      objective: %Objective{description: "venue fee rules"},
      constraints: [%Constraint{description: "official documentation only", kind: :scope}],
      notes: "prefer the venue's own fee schedule pages"
    }
  end

  defp plain_exchange_docs_theme do
    %Normalized{
      original_input: "exchange docs",
      normalized_text: "exchange docs",
      topic: "exchange docs",
      objective: %Objective{description: "official exchange documentation"},
      constraints: [%Constraint{description: "official documentation only", kind: :scope}],
      notes: "prefer the venue's own docs"
    }
  end

  defp docs_first_behavior_theme do
    %Normalized{
      original_input: "public API docs for order routing integration",
      normalized_text: "public api docs for order routing integration",
      topic: "order routing",
      domain_hints: [%DomainHint{label: "protocol integration"}],
      objective: %Objective{description: "public API docs"},
      constraints: [%Constraint{description: "official documentation only", kind: :scope}],
      notes: "compare sdk behavior across versions"
    }
  end

  defp docs_first_component_name_theme do
    %Normalized{
      original_input: "public API docs for order routing integration",
      normalized_text: "public api docs for order routing integration",
      topic: "order routing",
      domain_hints: [
        %DomainHint{label: "protocol integration"},
        %DomainHint{label: "exchange policy engine"}
      ],
      objective: %Objective{description: "public API docs"},
      constraints: [%Constraint{description: "official documentation only", kind: :scope}],
      notes: "compare sdk behavior across versions"
    }
  end

  defp docs_first_documentation_component_theme do
    %Normalized{
      original_input: "public API docs for order routing integration",
      normalized_text: "public api docs for order routing integration",
      topic: "order routing",
      domain_hints: [
        %DomainHint{label: "protocol integration"},
        %DomainHint{label: "exchange documentation sdk"}
      ],
      objective: %Objective{description: "public API docs"},
      constraints: [%Constraint{description: "official documentation only", kind: :scope}],
      notes: "compare sdk behavior across versions"
    }
  end

  defp docs_first_abbreviated_docs_component_theme do
    %Normalized{
      original_input: "public API docs for order routing integration",
      normalized_text: "public api docs for order routing integration",
      topic: "order routing",
      domain_hints: [
        %DomainHint{label: "protocol integration"},
        %DomainHint{label: "exchange docs sdk"}
      ],
      objective: %Objective{description: "public API docs"},
      constraints: [%Constraint{description: "official documentation only", kind: :scope}],
      notes: "compare sdk behavior across versions"
    }
  end

  defp docs_first_page_component_theme do
    %Normalized{
      original_input: "public API docs for order routing integration",
      normalized_text: "public api docs for order routing integration",
      topic: "order routing",
      domain_hints: [
        %DomainHint{label: "protocol integration"},
        %DomainHint{label: "exchange docs page renderer"}
      ],
      objective: %Objective{description: "public API docs"},
      constraints: [%Constraint{description: "official documentation only", kind: :scope}],
      notes: "compare sdk behavior across versions"
    }
  end

  defp direct_theme_text_page_component_theme do
    %Normalized{
      original_input: "exchange docs page renderer",
      normalized_text: "exchange docs page renderer",
      topic: "exchange docs page renderer",
      objective: %Objective{description: "public API docs"},
      constraints: [%Constraint{description: "official documentation only", kind: :scope}],
      notes: "compare renderer behavior across sdk versions"
    }
  end

  defp suffix_theme_text_page_component_theme do
    %Normalized{
      original_input: "renderer for exchange docs page",
      normalized_text: "renderer for exchange docs page",
      topic: "renderer for exchange docs page",
      objective: %Objective{description: "public API docs"},
      constraints: [%Constraint{description: "official documentation only", kind: :scope}],
      notes: "compare renderer behavior across sdk versions"
    }
  end

  defp protocol_paper_theme do
    %Normalized{
      original_input: "protocol incentive design paper",
      normalized_text: "protocol incentive design paper",
      topic: "protocol incentive design paper",
      objective: %Objective{description: "scholarly review"},
      notes: "research literature only"
    }
  end

  defp implementation_survey_paper_theme do
    %Normalized{
      original_input: "implementation survey paper",
      normalized_text: "implementation survey paper",
      topic: "implementation survey paper",
      objective: %Objective{description: "scholarly review"},
      notes: "research literature only"
    }
  end

  defp integration_incentive_design_paper_theme do
    %Normalized{
      original_input: "integration incentive design paper",
      normalized_text: "integration incentive design paper",
      topic: "integration incentive design paper",
      objective: %Objective{description: "scholarly review"},
      notes: "research literature only"
    }
  end

  defp api_usage_survey_paper_theme do
    %Normalized{
      original_input: "api usage survey paper",
      normalized_text: "api usage survey paper",
      topic: "api usage survey paper",
      objective: %Objective{description: "scholarly review"},
      notes: "research literature only"
    }
  end

  defp transformer_api_benchmarks_theme do
    %Normalized{
      original_input: "transformer api benchmarks",
      normalized_text: "transformer api benchmarks",
      topic: "transformer api benchmarks",
      domain_hints: [%DomainHint{label: "machine learning"}, %DomainHint{label: "AI safety"}],
      mechanism_hints: [%MechanismHint{label: "benchmark evaluation"}]
    }
  end

  defp transformer_api_alignment_theme do
    %Normalized{
      original_input: "transformer api alignment",
      normalized_text: "transformer api alignment",
      topic: "transformer api alignment",
      domain_hints: [%DomainHint{label: "machine learning"}, %DomainHint{label: "AI safety"}]
    }
  end

  defp transformer_docs_alignment_theme do
    %Normalized{
      original_input: "transformer docs alignment",
      normalized_text: "transformer docs alignment",
      topic: "transformer docs alignment",
      domain_hints: [%DomainHint{label: "machine learning"}, %DomainHint{label: "AI safety"}]
    }
  end

  defp transformer_sdk_alignment_theme do
    %Normalized{
      original_input: "transformer sdk alignment",
      normalized_text: "transformer sdk alignment",
      topic: "transformer sdk alignment",
      domain_hints: [%DomainHint{label: "machine learning"}, %DomainHint{label: "AI safety"}]
    }
  end

  defp ai_docs_alignment_theme do
    %Normalized{
      original_input: "ai docs alignment",
      normalized_text: "ai docs alignment",
      topic: "ai docs alignment"
    }
  end

  defp ml_sdk_alignment_theme do
    %Normalized{
      original_input: "ml sdk alignment",
      normalized_text: "ml sdk alignment",
      topic: "ml sdk alignment"
    }
  end

  defp normalized_theme_generator do
    phrase = phrase_generator()
    maybe_phrase = StreamData.one_of([StreamData.constant(nil), phrase])

    domain_hint =
      StreamData.map(phrase, fn label ->
        %DomainHint{label: label}
      end)

    mechanism_hint =
      StreamData.map(phrase, fn label ->
        %MechanismHint{label: label}
      end)

    objective =
      StreamData.map(phrase, fn description ->
        %Objective{description: description}
      end)

    constraint =
      StreamData.fixed_map(%{
        description: phrase,
        kind: StreamData.member_of([:scope, :technical, :temporal, :methodological])
      })
      |> StreamData.map(&struct!(Constraint, &1))

    StreamData.fixed_map(%{
      original_input: phrase,
      normalized_text: phrase,
      topic: phrase,
      domain_hints: StreamData.list_of(domain_hint, max_length: 2),
      mechanism_hints: StreamData.list_of(mechanism_hint, max_length: 2),
      objective: StreamData.one_of([StreamData.constant(nil), objective]),
      constraints: StreamData.list_of(constraint, max_length: 2),
      notes: maybe_phrase
    })
    |> StreamData.map(&struct!(Normalized, &1))
  end

  defp phrase_generator do
    StreamData.list_of(
      StreamData.string(:alphanumeric, min_length: 1, max_length: 12),
      min_length: 1,
      max_length: 4
    )
    |> StreamData.map(&Enum.join(&1, " "))
  end
end
