defmodule ResearchCore.Strategy.DuplicateSuppressor do
  @moduledoc """
  Predictably collapses near-duplicate strategy candidates using an inspectable signature.
  """

  alias ResearchCore.Strategy.{Classifier, Helpers, StrategyCandidate}

  @spec collapse(
          ResearchCore.Strategy.InputPackage.t(),
          [ResearchCore.Strategy.FormulaCandidate.t()],
          [StrategyCandidate.t()],
          keyword()
        ) :: %{candidates: [StrategyCandidate.t()], duplicate_groups: [map()]}
  def collapse(input_package, formulas, candidates, _opts \\ []) do
    grouped = Enum.group_by(candidates, &signature/1)

    grouped
    |> Enum.reduce(%{candidates: [], duplicate_groups: []}, fn {_signature, grouped_candidates},
                                                               acc ->
      [%StrategyCandidate{} = canonical | duplicates] = Enum.sort_by(grouped_candidates, & &1.id)

      merged =
        duplicates
        |> Enum.reduce(canonical, &merge/2)
        |> then(&Classifier.classify(input_package, formulas, &1))

      duplicate_group = %{
        canonical_candidate_id: merged.id,
        merged_candidate_ids: Enum.map(duplicates, & &1.id),
        signature: signature(merged)
      }

      %{
        candidates: acc.candidates ++ [merged],
        duplicate_groups:
          if duplicates == [] do
            acc.duplicate_groups
          else
            acc.duplicate_groups ++ [duplicate_group]
          end
      }
    end)
  end

  defp merge(%StrategyCandidate{} = duplicate, %StrategyCandidate{} = canonical) do
    %{
      canonical
      | formula_ids: Enum.uniq(canonical.formula_ids ++ duplicate.formula_ids),
        rule_candidates: uniq_structs(canonical.rule_candidates ++ duplicate.rule_candidates),
        required_features:
          uniq_structs(canonical.required_features ++ duplicate.required_features),
        required_datasets:
          uniq_structs(canonical.required_datasets ++ duplicate.required_datasets),
        execution_assumptions:
          uniq_structs(canonical.execution_assumptions ++ duplicate.execution_assumptions),
        sizing_assumptions:
          uniq_structs(canonical.sizing_assumptions ++ duplicate.sizing_assumptions),
        evidence_links: uniq_structs(canonical.evidence_links ++ duplicate.evidence_links),
        conflicting_evidence_links:
          uniq_structs(
            canonical.conflicting_evidence_links ++ duplicate.conflicting_evidence_links
          ),
        validation_hints: uniq_structs(canonical.validation_hints ++ duplicate.validation_hints),
        metric_hints: uniq_structs(canonical.metric_hints ++ duplicate.metric_hints),
        notes: Enum.uniq(canonical.notes ++ duplicate.notes),
        invalidation_reasons:
          Enum.uniq(canonical.invalidation_reasons ++ duplicate.invalidation_reasons)
    }
  end

  defp signature(candidate) do
    [
      Helpers.normalize_string(candidate.title),
      candidate.category,
      Helpers.normalize_string(candidate.market_or_domain_applicability),
      normalize_text(candidate.thesis),
      normalize_text(candidate.signal_or_rule),
      Enum.sort(candidate.formula_ids)
    ]
  end

  defp normalize_text(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp normalize_text(_value), do: nil

  defp uniq_structs(values) do
    values
    |> Enum.uniq_by(&Map.from_struct/1)
  end
end
