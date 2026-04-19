defmodule ResearchCore.Strategy.CandidateNormalizer do
  @moduledoc """
  Deterministically validates and normalizes provider-extracted strategy candidates.
  """

  alias ResearchCore.Strategy.{
    CandidateKind,
    Classifier,
    DataRequirement,
    EvidenceLink,
    ExecutionAssumption,
    FeatureRequirement,
    Helpers,
    Id,
    MetricHint,
    RuleCandidate,
    StrategyCandidate,
    StrategyCategory,
    StrategySpec,
    ValidationHint
  }

  @spec normalize(
          ResearchCore.Strategy.InputPackage.t(),
          [ResearchCore.Strategy.FormulaCandidate.t()],
          [map() | struct()]
        ) ::
          %{accepted: [StrategyCandidate.t()], rejected: [map()]}
  def normalize(input_package, formulas, raw_candidates) when is_list(raw_candidates) do
    formula_lookup = Map.new(formulas, &{&1.id, &1})

    raw_candidates
    |> Enum.with_index()
    |> Enum.reduce(%{accepted: [], rejected: []}, fn {raw_candidate, index}, acc ->
      case normalize_candidate(input_package, formula_lookup, raw_candidate, index) do
        {:ok, candidate} -> %{acc | accepted: acc.accepted ++ [candidate]}
        {:error, rejection} -> %{acc | rejected: acc.rejected ++ [rejection]}
      end
    end)
  end

  @spec to_specs(ResearchCore.Strategy.InputPackage.t(), [StrategyCandidate.t()], keyword()) ::
          [StrategySpec.t()]
  def to_specs(input_package, candidates, opts \\ []) do
    run_id = Keyword.get(opts, :strategy_extraction_run_id)

    Enum.map(candidates, fn %StrategyCandidate{} = candidate ->
      rule_ids = Enum.map(candidate.rule_candidates, & &1.id)

      %StrategySpec{
        id:
          Id.build("strategy_spec", %{
            candidate_id: candidate.id,
            synthesis_artifact_id: input_package.synthesis_artifact_id,
            formula_ids: candidate.formula_ids,
            rule_ids: rule_ids
          }),
        strategy_candidate_id: candidate.id,
        strategy_extraction_run_id: run_id,
        corpus_snapshot_id: input_package.corpus_snapshot_id,
        synthesis_run_id: input_package.synthesis_run_id,
        synthesis_artifact_id: input_package.synthesis_artifact_id,
        title: candidate.title,
        thesis: candidate.thesis,
        category: candidate.category,
        candidate_kind: candidate.candidate_kind,
        market_or_domain_applicability: candidate.market_or_domain_applicability,
        decision_rule: %{
          signal_or_rule: candidate.signal_or_rule,
          entry_condition: candidate.entry_condition,
          exit_condition: candidate.exit_condition,
          formula_ids: candidate.formula_ids,
          rule_ids: rule_ids
        },
        formula_ids: candidate.formula_ids,
        required_features: candidate.required_features,
        required_datasets: candidate.required_datasets,
        execution_assumptions: candidate.execution_assumptions,
        sizing_assumptions: candidate.sizing_assumptions,
        evidence_links: candidate.evidence_links,
        conflicting_evidence_links: candidate.conflicting_evidence_links,
        expected_edge_source: candidate.expected_edge_source,
        validation_hints: candidate.validation_hints,
        metric_hints: candidate.metric_hints,
        falsification_idea: candidate.falsification_idea,
        readiness: candidate.readiness,
        evidence_strength: candidate.evidence_strength,
        actionability: candidate.actionability,
        notes: candidate.notes,
        blocked_by: candidate.invalidation_reasons
      }
    end)
  end

  defp normalize_candidate(input_package, formula_lookup, raw_candidate, index) do
    title = Helpers.normalize_string(Helpers.fetch(raw_candidate, :title))
    thesis = Helpers.normalize_string(Helpers.fetch(raw_candidate, :thesis))

    category =
      Helpers.atomize(
        Helpers.fetch(raw_candidate, :category),
        StrategyCategory.values(),
        :execution_strategy
      )

    candidate_kind =
      Helpers.atomize(
        Helpers.fetch(raw_candidate, :candidate_kind),
        CandidateKind.values(),
        :speculative_not_backtestable
      )

    market =
      Helpers.normalize_string(Helpers.fetch(raw_candidate, :market_or_domain_applicability))

    citation_keys =
      Helpers.fetch(raw_candidate, :evidence_references, []) |> Helpers.normalize_string_list()

    conflicting_keys =
      Helpers.fetch(raw_candidate, :conflicting_or_cautionary_evidence, [])
      |> Helpers.normalize_string_list()

    evidence_pairs = normalize_evidence_pairs(raw_candidate, :evidence_pairs)

    conflicting_evidence_pairs =
      normalize_evidence_pairs(raw_candidate, :conflicting_evidence_pairs)

    section_ids =
      raw_candidate
      |> Helpers.fetch(:source_section_ids, [])
      |> Helpers.normalize_string_list()
      |> Enum.map(&Helpers.slug/1)
      |> Enum.reject(&(&1 == :unknown_section))

    formula_ids =
      Helpers.fetch(raw_candidate, :formula_references, []) |> Helpers.normalize_string_list()

    signal_or_rule =
      Helpers.normalize_string(Helpers.fetch(raw_candidate, :direct_signal_or_rule))

    entry_condition = Helpers.normalize_string(Helpers.fetch(raw_candidate, :entry_condition))
    exit_condition = Helpers.normalize_string(Helpers.fetch(raw_candidate, :exit_condition))
    unknown_keys = citation_keys -- Map.keys(input_package.resolved_records)
    unknown_conflicting_keys = conflicting_keys -- Map.keys(input_package.resolved_records)
    unknown_formula_ids = formula_ids -- Map.keys(formula_lookup)

    cond do
      title == nil ->
        rejection(
          :malformed_strategy_candidate,
          "strategy title is required",
          raw_candidate,
          :fatal
        )

      thesis == nil ->
        rejection(
          :malformed_strategy_candidate,
          "strategy thesis is required",
          raw_candidate,
          :warning
        )

      market == nil ->
        rejection(
          :malformed_strategy_candidate,
          "market or domain applicability is required",
          raw_candidate,
          :warning
        )

      citation_keys == [] ->
        rejection(
          :strategy_without_evidence,
          "strategy candidates must cite supporting records",
          raw_candidate,
          :fatal
        )

      unknown_keys != [] ->
        rejection(
          :unknown_citation_key,
          "strategy candidate references unknown citation keys: #{Enum.join(unknown_keys, ", ")}",
          raw_candidate,
          :fatal,
          %{unknown_keys: unknown_keys}
        )

      unknown_conflicting_keys != [] ->
        rejection(
          :unknown_conflicting_citation_key,
          "strategy candidate references unknown cautionary citations: #{Enum.join(unknown_conflicting_keys, ", ")}",
          raw_candidate,
          :fatal,
          %{unknown_keys: unknown_conflicting_keys}
        )

      unknown_formula_ids != [] ->
        rejection(
          :unknown_formula_reference,
          "strategy candidate references unknown formula IDs: #{Enum.join(unknown_formula_ids, ", ")}",
          raw_candidate,
          :fatal,
          %{unknown_formula_ids: unknown_formula_ids}
        )

      signal_or_rule == nil and formula_ids == [] ->
        rejection(
          :unsupported_candidate,
          "narrative filler without a signal, rule, or formula reference is rejected",
          raw_candidate,
          :warning
        )

      section_ids == [] ->
        rejection(
          :missing_strategy_source_section,
          "strategy candidates must map to report sections",
          raw_candidate,
          :warning
        )

      true ->
        relation = if signal_or_rule in [nil, ""], do: :supports_thesis, else: :supports_rule

        conflict_note =
          Helpers.normalize_string(Helpers.fetch(raw_candidate, :conflict_note)) || thesis

        with {:ok, evidence_links} <-
               build_evidence_links(
                 input_package,
                 raw_candidate,
                 section_ids,
                 citation_keys,
                 relation,
                 signal_or_rule || thesis,
                 evidence_pairs,
                 :unlinked_strategy_provenance,
                 :ambiguous_strategy_provenance
               ),
             {:ok, conflicting_links} <-
               build_evidence_links(
                 input_package,
                 raw_candidate,
                 section_ids,
                 conflicting_keys,
                 :cautionary,
                 conflict_note,
                 conflicting_evidence_pairs,
                 :unlinked_strategy_provenance,
                 :ambiguous_strategy_provenance
               ) do
          rule_candidate = %RuleCandidate{
            id:
              Id.build("rule_candidate", %{
                title: title,
                signal_or_rule: signal_or_rule || thesis,
                citation_keys: citation_keys
              }),
            signal_or_rule: signal_or_rule || thesis,
            entry_condition: entry_condition,
            exit_condition: exit_condition,
            source_section_ids: section_ids,
            supporting_citation_keys: citation_keys,
            evidence_links: evidence_links,
            notes: Helpers.normalize_notes(Helpers.fetch(raw_candidate, :notes, []))
          }

          candidate = %StrategyCandidate{
            id:
              Id.build("strategy_candidate", %{
                index: index,
                title: title,
                thesis: thesis,
                category: category,
                market: market,
                formula_ids: formula_ids
              }),
            title: title,
            thesis: thesis,
            category: category,
            candidate_kind: candidate_kind,
            market_or_domain_applicability: market,
            signal_or_rule: signal_or_rule,
            entry_condition: entry_condition,
            exit_condition: exit_condition,
            formula_ids: formula_ids,
            rule_candidates: [rule_candidate],
            required_features: normalize_features(raw_candidate),
            required_datasets: normalize_datasets(raw_candidate),
            execution_assumptions: normalize_assumptions(raw_candidate, :execution_assumptions),
            sizing_assumptions: normalize_assumptions(raw_candidate, :sizing_assumptions),
            evidence_links: evidence_links,
            conflicting_evidence_links: conflicting_links,
            expected_edge_source:
              Helpers.normalize_string(Helpers.fetch(raw_candidate, :expected_edge_source)),
            validation_hints: normalize_validation_hints(raw_candidate),
            metric_hints: normalize_metric_hints(raw_candidate),
            falsification_idea:
              Helpers.normalize_string(Helpers.fetch(raw_candidate, :falsification_idea)),
            notes: Helpers.normalize_notes(Helpers.fetch(raw_candidate, :notes, [])),
            invalidation_reasons: []
          }

          {:ok, Classifier.classify(input_package, Map.values(formula_lookup), candidate)}
        end
    end
  end

  defp build_evidence_links(
         _input_package,
         _raw_candidate,
         _section_ids,
         [],
         _relation,
         _quote,
         _evidence_pairs,
         _unlinked_type,
         _ambiguous_type
       ),
       do: {:ok, []}

  defp build_evidence_links(
         input_package,
         raw_candidate,
         section_ids,
         citation_keys,
         relation,
         quote,
         evidence_pairs,
         unlinked_type,
         ambiguous_type
       ) do
    with {:ok, link_pairs} <-
           resolve_link_pairs(
             input_package,
             raw_candidate,
             section_ids,
             citation_keys,
             evidence_pairs,
             unlinked_type,
             ambiguous_type
           ) do
      links =
        Enum.map(link_pairs, fn %{
                                  section_id: section_id,
                                  citation_key: citation_key,
                                  quote: pair_quote
                                } ->
          record = Map.fetch!(input_package.resolved_records, citation_key)
          section = Map.fetch!(input_package.section_lookup, section_id)

          %EvidenceLink{
            section_id: section_id,
            section_heading: section.heading,
            citation_key: citation_key,
            record_id: record.record_id,
            relation: relation,
            quote: pair_quote || quote,
            note: if(relation == :cautionary, do: pair_quote || quote),
            provenance_reference: record.provenance_reference
          }
        end)

      {:ok, links}
    end
  end

  defp resolve_link_pairs(
         _input_package,
         _raw_candidate,
         _section_ids,
         [],
         _evidence_pairs,
         _unlinked_type,
         _ambiguous_type
       ),
       do: {:ok, []}

  defp resolve_link_pairs(
         input_package,
         raw_candidate,
         section_ids,
         citation_keys,
         evidence_pairs,
         unlinked_type,
         ambiguous_type
       ) do
    if evidence_pairs != [] do
      validate_explicit_pairs(
        input_package,
        raw_candidate,
        section_ids,
        citation_keys,
        evidence_pairs,
        unlinked_type
      )
    else
      infer_link_pairs(
        input_package,
        raw_candidate,
        section_ids,
        citation_keys,
        unlinked_type,
        ambiguous_type
      )
    end
  end

  defp validate_explicit_pairs(
         input_package,
         raw_candidate,
         section_ids,
         citation_keys,
         evidence_pairs,
         unlinked_type
       ) do
    pair_section_ids = Enum.map(evidence_pairs, & &1.section_id) |> Enum.uniq()
    pair_citation_keys = Enum.map(evidence_pairs, & &1.citation_key) |> Enum.uniq()
    unknown_sections = pair_section_ids -- section_ids
    unknown_citations = pair_citation_keys -- citation_keys
    missing_citations = citation_keys -- pair_citation_keys

    cond do
      unknown_sections != [] ->
        rejection(
          :invalid_strategy_evidence_pair,
          "strategy evidence pairs reference undeclared source sections: #{Enum.join(Enum.map(unknown_sections, &Atom.to_string/1), ", ")}",
          raw_candidate,
          :fatal,
          %{unknown_sections: Enum.map(unknown_sections, &Atom.to_string/1)}
        )

      unknown_citations != [] ->
        rejection(
          :invalid_strategy_evidence_pair,
          "strategy evidence pairs reference undeclared citation keys: #{Enum.join(unknown_citations, ", ")}",
          raw_candidate,
          :fatal,
          %{unknown_citation_keys: unknown_citations}
        )

      Enum.any?(evidence_pairs, fn pair ->
        not section_cites_key?(input_package, pair.section_id, pair.citation_key)
      end) ->
        rejection(
          unlinked_type,
          "strategy evidence pairs must match actual section citations",
          raw_candidate,
          :fatal,
          %{
            invalid_pairs:
              Enum.map(evidence_pairs, fn pair ->
                %{section_id: Atom.to_string(pair.section_id), citation_key: pair.citation_key}
              end)
          }
        )

      missing_citations != [] ->
        rejection(
          unlinked_type,
          "strategy citations must each map to an explicit section/citation pair",
          raw_candidate,
          :fatal,
          %{unlinked_keys: missing_citations}
        )

      true ->
        {:ok, evidence_pairs}
    end
  end

  defp infer_link_pairs(
         input_package,
         raw_candidate,
         section_ids,
         citation_keys,
         unlinked_type,
         ambiguous_type
       ) do
    citation_keys
    |> Enum.reduce_while({:ok, []}, fn citation_key, {:ok, acc} ->
      matching_sections =
        Enum.filter(section_ids, &section_cites_key?(input_package, &1, citation_key))

      case matching_sections do
        [section_id] ->
          {:cont,
           {:ok, acc ++ [%{section_id: section_id, citation_key: citation_key, quote: nil}]}}

        [] ->
          {:halt,
           rejection(
             unlinked_type,
             "strategy citations must appear in at least one cited source section: #{citation_key}",
             raw_candidate,
             :fatal,
             %{
               unlinked_keys: [citation_key],
               source_section_ids: Enum.map(section_ids, &Atom.to_string/1)
             }
           )}

        _many ->
          {:halt,
           rejection(
             ambiguous_type,
             "strategy citation #{citation_key} appears in multiple source sections; explicit evidence pairs are required",
             raw_candidate,
             :fatal,
             %{
               citation_key: citation_key,
               source_section_ids: Enum.map(matching_sections, &Atom.to_string/1)
             }
           )}
      end
    end)
  end

  defp section_cites_key?(input_package, section_id, citation_key) do
    case Map.get(input_package.section_lookup, section_id) do
      nil -> false
      section -> citation_key in section.cited_keys
    end
  end

  defp normalize_features(raw_candidate) do
    raw_candidate
    |> Helpers.fetch(:required_features, [])
    |> List.wrap()
    |> Enum.map(fn feature ->
      %FeatureRequirement{
        name: Helpers.normalize_string(Helpers.fetch(feature, :name)) || "unspecified_feature",
        description: Helpers.normalize_string(Helpers.fetch(feature, :description)) || "",
        status:
          Helpers.atomize(
            Helpers.fetch(feature, :status),
            [:available, :needs_build, :unknown],
            :unknown
          ),
        source: Helpers.normalize_string(Helpers.fetch(feature, :source)),
        citation_keys:
          Helpers.fetch(feature, :citation_keys, []) |> Helpers.normalize_string_list()
      }
    end)
  end

  defp normalize_datasets(raw_candidate) do
    raw_candidate
    |> Helpers.fetch(:required_datasets, [])
    |> List.wrap()
    |> Enum.map(fn dataset ->
      %DataRequirement{
        name: Helpers.normalize_string(Helpers.fetch(dataset, :name)) || "unspecified_dataset",
        description: Helpers.normalize_string(Helpers.fetch(dataset, :description)) || "",
        mapping_status:
          Helpers.atomize(
            Helpers.fetch(dataset, :mapping_status),
            [:mapped, :needs_mapping, :unknown],
            :unknown
          ),
        source: Helpers.normalize_string(Helpers.fetch(dataset, :source)),
        citation_keys:
          Helpers.fetch(dataset, :citation_keys, []) |> Helpers.normalize_string_list()
      }
    end)
  end

  defp normalize_assumptions(raw_candidate, key) do
    raw_candidate
    |> Helpers.fetch(key, [])
    |> List.wrap()
    |> Enum.map(fn assumption ->
      %ExecutionAssumption{
        kind:
          Helpers.atomize(
            Helpers.fetch(assumption, :kind),
            [:execution, :sizing, :liquidity, :latency, :other],
            :other
          ),
        description: Helpers.normalize_string(Helpers.fetch(assumption, :description)) || "",
        blocking?: Helpers.fetch(assumption, :blocking?, false) in [true, "true", 1, "1"],
        citation_keys:
          Helpers.fetch(assumption, :citation_keys, []) |> Helpers.normalize_string_list()
      }
    end)
  end

  defp normalize_validation_hints(raw_candidate) do
    raw_candidate
    |> Helpers.fetch(:validation_hints, [])
    |> List.wrap()
    |> Enum.map(fn hint ->
      %ValidationHint{
        kind:
          Helpers.atomize(
            Helpers.fetch(hint, :kind),
            [:ablation, :holdout, :stress, :sanity_check, :other],
            :other
          ),
        description: Helpers.normalize_string(Helpers.fetch(hint, :description)) || "",
        priority: Helpers.atomize(Helpers.fetch(hint, :priority), [:high, :medium, :low], nil),
        blockers: Helpers.fetch(hint, :blockers, []) |> Helpers.normalize_string_list()
      }
    end)
  end

  defp normalize_metric_hints(raw_candidate) do
    raw_candidate
    |> Helpers.fetch(:candidate_metrics, [])
    |> List.wrap()
    |> Enum.map(fn metric ->
      %MetricHint{
        name: Helpers.normalize_string(Helpers.fetch(metric, :name)) || "metric",
        description: Helpers.normalize_string(Helpers.fetch(metric, :description)) || "",
        direction:
          Helpers.atomize(
            Helpers.fetch(metric, :direction),
            [:maximize, :minimize, :monitor],
            :monitor
          )
      }
    end)
  end

  defp normalize_evidence_pairs(raw_candidate, key) do
    raw_candidate
    |> Helpers.fetch(key, [])
    |> List.wrap()
    |> Enum.map(fn pair ->
      %{
        section_id: pair |> Helpers.fetch(:section_id) |> normalize_section_id(),
        citation_key: pair |> Helpers.fetch(:citation_key) |> Helpers.normalize_string(),
        quote: Helpers.normalize_string(Helpers.fetch(pair, :quote))
      }
    end)
    |> Enum.reject(fn pair -> is_nil(pair.section_id) or is_nil(pair.citation_key) end)
    |> Enum.uniq()
  end

  defp normalize_section_id(value) do
    value
    |> Helpers.normalize_string_list()
    |> Enum.map(&Helpers.slug/1)
    |> Enum.reject(&(&1 == :unknown_section))
    |> List.first()
  end

  defp rejection(type, message, raw_candidate, severity, details \\ %{}) do
    {:error,
     %{
       type: type,
       message: message,
       severity: severity,
       raw_candidate: raw_candidate,
       details: details
     }}
  end
end
