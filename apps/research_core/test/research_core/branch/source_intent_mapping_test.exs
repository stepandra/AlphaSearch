defmodule ResearchCore.Branch.SourceIntentMappingTest do
  use ExUnit.Case, async: true

  alias ResearchCore.Branch.{Branch, SourceIntentMapping}
  alias ResearchCore.Theme.{Constraint, DomainHint, MechanismHint, Normalized, Objective}

  describe "recommend/2" do
    test "prefers economics working-paper families for economics-oriented research" do
      branch = %Branch{
        kind: :direct,
        label: "market design working paper evidence",
        rationale: "Direct economics literature search",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "market design literature",
        normalized_text: "market design literature",
        topic: "market design literature",
        domain_hints: [%DomainHint{label: "economics"}, %DomainHint{label: "market design"}],
        objective: %Objective{description: "working paper evidence"}
      }

      assert %{
               preferred_source_families: [
                 :econ_working_papers,
                 :academic_preprints,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "econom"
    end

    test "prefers academic preprints and proceedings for machine-learning themes" do
      branch = %Branch{
        kind: :direct,
        label: "transformer alignment benchmarks",
        rationale: "Direct ML literature search",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "transformer alignment benchmarks",
        normalized_text: "transformer alignment benchmarks",
        topic: "transformer alignment benchmarks",
        domain_hints: [%DomainHint{label: "machine learning"}, %DomainHint{label: "AI safety"}],
        mechanism_hints: [%MechanismHint{label: "benchmark evaluation"}]
      }

      assert %{
               preferred_source_families: [
                 :academic_preprints,
                 :conference_proceedings,
                 :general_web
               ]
             } = SourceIntentMapping.recommend(branch, theme)
    end

    test "uses branch intent to prefer official docs and repositories for method-style protocol work" do
      theme = %Normalized{
        original_input: "exchange api integration",
        normalized_text: "exchange api integration",
        topic: "exchange api integration",
        domain_hints: [%DomainHint{label: "protocol integration"}],
        constraints: [%Constraint{description: "public docs only", kind: :scope}]
      }

      docs_branch = %Branch{
        kind: :method,
        label: "API integration methods for protocol order routing",
        rationale: "Focus on implementation workflow",
        theme_relation: "methodology"
      }

      fees_branch = %Branch{
        kind: :direct,
        label: "exchange fee schedule and venue behavior",
        rationale: "Focus on exchange policy details",
        theme_relation: "verbatim"
      }

      assert %{
               preferred_source_families: [
                 :official_docs,
                 :code_repositories,
                 :official_sites,
                 :general_web
               ]
             } = SourceIntentMapping.recommend(docs_branch, theme)

      assert %{
               preferred_source_families: [
                 :official_sites,
                 :official_docs,
                 :general_web
               ]
             } = SourceIntentMapping.recommend(fees_branch, theme)
    end

    test "uses docs-first theme intent for neutral direct branches" do
      branch = %Branch{
        kind: :direct,
        label: "order routing",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "public API docs for order routing integration",
        normalized_text: "public api docs for order routing integration",
        topic: "order routing",
        objective: %Objective{description: "public API docs"},
        domain_hints: [%DomainHint{label: "protocol integration"}],
        constraints: [%Constraint{description: "official documentation only", kind: :scope}]
      }

      assert %{
               preferred_source_families: [
                 :official_docs,
                 :code_repositories,
                 :official_sites,
                 :general_web
               ]
             } = SourceIntentMapping.recommend(branch, theme)
    end

    test "prefers official sites first when docs language also targets exchange fee rules" do
      branch = %Branch{
        kind: :direct,
        label: "exchange docs fee schedule",
        rationale: "Direct exploration of venue fee documentation",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "exchange docs fee schedule",
        normalized_text: "exchange docs fee schedule",
        topic: "exchange docs fee schedule",
        objective: %Objective{description: "venue fee rules"},
        constraints: [%Constraint{description: "official documentation only", kind: :scope}],
        notes: "prefer the venue's own fee schedule pages"
      }

      assert %{
               preferred_source_families: [
                 :official_sites,
                 :official_docs,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "venue"
    end

    test "prefers official sites first for plain exchange docs direct intent" do
      branch = %Branch{
        kind: :direct,
        label: "exchange docs",
        rationale: "Direct exploration of venue documentation",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "exchange docs",
        normalized_text: "exchange docs",
        topic: "exchange docs",
        objective: %Objective{description: "official exchange documentation"},
        constraints: [%Constraint{description: "official documentation only", kind: :scope}],
        notes: "prefer the venue's own docs"
      }

      assert %{
               preferred_source_families: [
                 :official_sites,
                 :official_docs,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "official sites"
    end

    test "does not treat plain exchange docs labels on non-direct branches as official-site intent" do
      branch = %Branch{
        kind: :analog,
        label: "exchange docs",
        rationale: "Explores a parallel documentation domain",
        theme_relation: "analogy"
      }

      theme = %Normalized{
        original_input: "exchange docs",
        normalized_text: "exchange docs",
        topic: "exchange docs",
        objective: %Objective{description: "official exchange documentation"},
        constraints: [%Constraint{description: "official documentation only", kind: :scope}],
        notes: "prefer the venue's own docs"
      }

      assert %{
               preferred_source_families: [
                 :official_docs,
                 :code_repositories,
                 :official_sites,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "documentation"
    end

    test "does not treat incidental behavior wording in docs-first notes as official-site intent" do
      branch = %Branch{
        kind: :direct,
        label: "order routing",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "public API docs for order routing integration",
        normalized_text: "public api docs for order routing integration",
        topic: "order routing",
        objective: %Objective{description: "public API docs"},
        domain_hints: [%DomainHint{label: "protocol integration"}],
        constraints: [%Constraint{description: "official documentation only", kind: :scope}],
        notes: "compare sdk behavior across versions"
      }

      assert %{
               preferred_source_families: [
                 :official_docs,
                 :code_repositories,
                 :official_sites,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "documentation"
    end

    test "does not treat component names like exchange policy engine as official-site intent" do
      branch = %Branch{
        kind: :direct,
        label: "order routing",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "public API docs for order routing integration",
        normalized_text: "public api docs for order routing integration",
        topic: "order routing",
        objective: %Objective{description: "public API docs"},
        domain_hints: [
          %DomainHint{label: "protocol integration"},
          %DomainHint{label: "exchange policy engine"}
        ],
        constraints: [%Constraint{description: "official documentation only", kind: :scope}],
        notes: "compare sdk behavior across versions"
      }

      assert %{
               preferred_source_families: [
                 :official_docs,
                 :code_repositories,
                 :official_sites,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "documentation"
    end

    test "does not treat docs component labels like exchange documentation sdk as official-site intent" do
      branch = %Branch{
        kind: :direct,
        label: "order routing",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "public API docs for order routing integration",
        normalized_text: "public api docs for order routing integration",
        topic: "order routing",
        objective: %Objective{description: "public API docs"},
        domain_hints: [
          %DomainHint{label: "protocol integration"},
          %DomainHint{label: "exchange documentation sdk"}
        ],
        constraints: [%Constraint{description: "official documentation only", kind: :scope}],
        notes: "compare sdk behavior across versions"
      }

      assert %{
               preferred_source_families: [
                 :official_docs,
                 :code_repositories,
                 :official_sites,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "documentation"
    end

    test "does not treat abbreviated docs component labels like exchange docs sdk as official-site intent" do
      branch = %Branch{
        kind: :direct,
        label: "order routing",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "public API docs for order routing integration",
        normalized_text: "public api docs for order routing integration",
        topic: "order routing",
        objective: %Objective{description: "public API docs"},
        domain_hints: [
          %DomainHint{label: "protocol integration"},
          %DomainHint{label: "exchange docs sdk"}
        ],
        constraints: [%Constraint{description: "official documentation only", kind: :scope}],
        notes: "compare sdk behavior across versions"
      }

      assert %{
               preferred_source_families: [
                 :official_docs,
                 :code_repositories,
                 :official_sites,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "documentation"
    end

    test "does not treat docs component labels like exchange docs page renderer as official-site intent" do
      branch = %Branch{
        kind: :direct,
        label: "order routing",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "public API docs for order routing integration",
        normalized_text: "public api docs for order routing integration",
        topic: "order routing",
        objective: %Objective{description: "public API docs"},
        domain_hints: [
          %DomainHint{label: "protocol integration"},
          %DomainHint{label: "exchange docs page renderer"}
        ],
        constraints: [%Constraint{description: "official documentation only", kind: :scope}],
        notes: "compare sdk behavior across versions"
      }

      assert %{
               preferred_source_families: [
                 :official_docs,
                 :code_repositories,
                 :official_sites,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "documentation"
    end

    test "does not treat direct theme text like exchange docs page renderer as official-site intent" do
      branch = %Branch{
        kind: :direct,
        label: "exchange docs page renderer",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "exchange docs page renderer",
        normalized_text: "exchange docs page renderer",
        topic: "exchange docs page renderer",
        objective: %Objective{description: "public API docs"},
        constraints: [%Constraint{description: "official documentation only", kind: :scope}],
        notes: "compare renderer behavior across sdk versions"
      }

      assert %{
               preferred_source_families: [
                 :official_docs,
                 :code_repositories,
                 :official_sites,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "documentation"
    end

    test "does not treat suffix-shaped theme text like renderer for exchange docs page as official-site intent" do
      branch = %Branch{
        kind: :direct,
        label: "renderer for exchange docs page",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "renderer for exchange docs page",
        normalized_text: "renderer for exchange docs page",
        topic: "renderer for exchange docs page",
        objective: %Objective{description: "public API docs"},
        constraints: [%Constraint{description: "official documentation only", kind: :scope}],
        notes: "compare renderer behavior across sdk versions"
      }

      assert %{
               preferred_source_families: [
                 :official_docs,
                 :code_repositories,
                 :official_sites,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "documentation"
    end

    test "prefers academic sources for scholarly protocol-paper themes" do
      branch = %Branch{
        kind: :direct,
        label: "protocol incentive design paper",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "protocol incentive design paper",
        normalized_text: "protocol incentive design paper",
        topic: "protocol incentive design paper",
        objective: %Objective{description: "scholarly review"},
        notes: "research literature only"
      }

      assert %{
               preferred_source_families: [
                 :academic_preprints,
                 :conference_proceedings,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "research"
    end

    test "prefers academic sources for scholarly themes that only contain generic docs words" do
      for label <- ["implementation survey paper", "integration incentive design paper"] do
        branch = %Branch{
          kind: :direct,
          label: label,
          rationale: "Direct exploration of the stated theme",
          theme_relation: "verbatim"
        }

        theme = %Normalized{
          original_input: label,
          normalized_text: label,
          topic: label,
          objective: %Objective{description: "scholarly review"},
          notes: "research literature only"
        }

        assert %{
                 preferred_source_families: [
                   :academic_preprints,
                   :conference_proceedings,
                   :general_web
                 ],
                 rationale: rationale
               } = SourceIntentMapping.recommend(branch, theme)

        assert String.downcase(rationale) =~ "research"
      end
    end

    test "prefers academic sources for scholarly themes that only contain strong docs keywords" do
      branch = %Branch{
        kind: :direct,
        label: "api usage survey paper",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "api usage survey paper",
        normalized_text: "api usage survey paper",
        topic: "api usage survey paper",
        objective: %Objective{description: "scholarly review"},
        notes: "research literature only"
      }

      assert %{
               preferred_source_families: [
                 :academic_preprints,
                 :conference_proceedings,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "research"
    end

    test "prefers academic sources for ML benchmark themes even when they include docs keywords" do
      branch = %Branch{
        kind: :direct,
        label: "transformer api benchmarks",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "transformer api benchmarks",
        normalized_text: "transformer api benchmarks",
        topic: "transformer api benchmarks",
        domain_hints: [%DomainHint{label: "machine learning"}, %DomainHint{label: "AI safety"}],
        mechanism_hints: [%MechanismHint{label: "benchmark evaluation"}]
      }

      assert %{
               preferred_source_families: [
                 :academic_preprints,
                 :conference_proceedings,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "machine"
    end

    test "prefers academic sources for clear ML themes when api is the only docs keyword" do
      branch = %Branch{
        kind: :direct,
        label: "transformer api alignment",
        rationale: "Direct exploration of the stated theme",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "transformer api alignment",
        normalized_text: "transformer api alignment",
        topic: "transformer api alignment",
        domain_hints: [%DomainHint{label: "machine learning"}, %DomainHint{label: "AI safety"}]
      }

      assert %{
               preferred_source_families: [
                 :academic_preprints,
                 :conference_proceedings,
                 :general_web
               ],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "machine"
    end

    test "prefers academic sources for clear ML themes even with strong docs keywords" do
      for label <- ["transformer docs alignment", "transformer sdk alignment"] do
        branch = %Branch{
          kind: :direct,
          label: label,
          rationale: "Direct exploration of the stated theme",
          theme_relation: "verbatim"
        }

        theme = %Normalized{
          original_input: label,
          normalized_text: label,
          topic: label,
          domain_hints: [%DomainHint{label: "machine learning"}, %DomainHint{label: "AI safety"}]
        }

        assert %{
                 preferred_source_families: [
                   :academic_preprints,
                   :conference_proceedings,
                   :general_web
                 ],
                 rationale: rationale
               } = SourceIntentMapping.recommend(branch, theme)

        assert String.downcase(rationale) =~ "machine"
      end
    end

    test "prefers academic sources for clear ML abbreviation themes even with strong docs keywords" do
      for label <- ["ai docs alignment", "ml sdk alignment"] do
        branch = %Branch{
          kind: :direct,
          label: label,
          rationale: "Direct exploration of the stated theme",
          theme_relation: "verbatim"
        }

        theme = %Normalized{
          original_input: label,
          normalized_text: label,
          topic: label
        }

        assert %{
                 preferred_source_families: [
                   :academic_preprints,
                   :conference_proceedings,
                   :general_web
                 ],
                 rationale: rationale
               } = SourceIntentMapping.recommend(branch, theme)

        assert String.downcase(rationale) =~ "machine"
      end
    end

    test "does not infer academic or ml intent from boilerplate branch text" do
      theme = %Normalized{
        original_input: "order routing",
        normalized_text: "order routing",
        topic: "order routing"
      }

      broader_branch = %Branch{
        kind: :broader,
        label: "general context of order routing",
        rationale: "Widens the framing to capture adjacent literature and context",
        theme_relation: "superset"
      }

      analog_branch = %Branch{
        kind: :analog,
        label: "cross-domain parallels to order routing",
        rationale: "Explores a parallel domain for transferable patterns and insights",
        theme_relation: "analogy"
      }

      assert %{preferred_source_families: [:general_web]} =
               SourceIntentMapping.recommend(broader_branch, theme)

      assert %{preferred_source_families: [:general_web]} =
               SourceIntentMapping.recommend(analog_branch, theme)
    end

    test "falls back to general web when no stronger source intent is present" do
      branch = %Branch{
        kind: :direct,
        label: "ambiguous calibration topic",
        rationale: "Direct but underspecified search",
        theme_relation: "verbatim"
      }

      theme = %Normalized{
        original_input: "ambiguous calibration topic",
        normalized_text: "ambiguous calibration topic",
        topic: "ambiguous calibration topic"
      }

      assert %{
               preferred_source_families: [:general_web],
               rationale: rationale
             } = SourceIntentMapping.recommend(branch, theme)

      assert String.downcase(rationale) =~ "fallback"
    end

    test "is deterministic for the same branch and theme" do
      branch = %Branch{
        kind: :method,
        label: "API integration methods for protocol order routing",
        rationale: "Focus on implementation workflow",
        theme_relation: "methodology"
      }

      theme = %Normalized{
        original_input: "exchange api integration",
        normalized_text: "exchange api integration",
        topic: "exchange api integration",
        domain_hints: [%DomainHint{label: "protocol integration"}]
      }

      assert SourceIntentMapping.recommend(branch, theme) ==
               SourceIntentMapping.recommend(branch, theme)
    end
  end
end
