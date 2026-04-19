defmodule ResearchCore.Strategy.Classifier do
  @moduledoc false

  alias ResearchCore.Strategy.{Helpers, StrategyCandidate}

  @spec classify(
          ResearchCore.Strategy.InputPackage.t(),
          [ResearchCore.Strategy.FormulaCandidate.t()],
          StrategyCandidate.t()
        ) :: StrategyCandidate.t()
  def classify(input_package, formulas, %StrategyCandidate{} = candidate) do
    formula_lookup = Map.new(formulas, &{&1.id, &1})

    blocking_formula? =
      Enum.any?(candidate.formula_ids, &(Map.get(formula_lookup, &1, %{}).blocked? == true))

    missing_dataset_mapping? =
      Enum.any?(candidate.required_datasets, &(&1.mapping_status != :mapped))

    missing_features? = Enum.any?(candidate.required_features, &(&1.status != :available))
    incomplete_formula_strategy? = candidate.candidate_kind == :formula_backed_incomplete_strategy
    analog_transfer? = candidate.candidate_kind == :analog_transfer_candidate
    {evidence_strength, direct_count, analog_count} = evidence_strength(input_package, candidate)
    analog_only? = direct_count == 0 and analog_count > 0

    readiness =
      cond do
        candidate.invalidation_reasons != [] ->
          :reject

        candidate.signal_or_rule in [nil, ""] and candidate.formula_ids == [] ->
          :reject

        blocking_formula? ->
          :needs_formula_completion

        incomplete_formula_strategy? ->
          :needs_formula_completion

        analog_transfer? ->
          :needs_formula_completion

        analog_only? ->
          :needs_formula_completion

        missing_dataset_mapping? ->
          :needs_data_mapping

        missing_features? ->
          :needs_feature_build

        evidence_strength == :speculative and
            candidate.candidate_kind == :speculative_not_backtestable ->
          :needs_formula_completion

        true ->
          :ready_for_backtest
      end

    actionability = actionability(readiness, candidate.candidate_kind, analog_only?)

    %{
      candidate
      | readiness: readiness,
        evidence_strength: evidence_strength,
        actionability: actionability
    }
  end

  defp evidence_strength(input_package, candidate) do
    cited_records =
      candidate.evidence_links
      |> Enum.map(&Map.get(input_package.resolved_records, &1.citation_key))
      |> Enum.reject(&is_nil/1)

    direct_count = Enum.count(cited_records, &(&1.classification == :accepted_core))
    analog_count = Enum.count(cited_records, &(&1.classification == :accepted_analog))

    average_strength =
      cited_records
      |> Enum.map(fn record -> Helpers.fetch(record.scores, :evidence_strength, 0.0) end)
      |> average()

    strength =
      cond do
        candidate.candidate_kind == :speculative_not_backtestable -> :speculative
        direct_count >= 2 and average_strength >= 0.75 -> :strong
        direct_count >= 1 and average_strength >= 0.55 -> :moderate
        analog_count >= 1 and average_strength >= 0.4 -> :weak
        cited_records == [] -> :speculative
        true -> :weak
      end

    {strength, direct_count, analog_count}
  end

  defp actionability(:ready_for_backtest, _kind, _analog_only?), do: :immediate
  defp actionability(:needs_feature_build, _kind, _analog_only?), do: :near_term
  defp actionability(:needs_data_mapping, _kind, _analog_only?), do: :near_term

  defp actionability(:needs_formula_completion, _kind, true), do: :exploratory

  defp actionability(:needs_formula_completion, kind, _analog_only?)
       when kind in [:analog_transfer_candidate, :speculative_not_backtestable],
       do: :exploratory

  defp actionability(:needs_formula_completion, _kind, _analog_only?), do: :near_term
  defp actionability(:reject, _kind, _analog_only?), do: :background_only

  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)
end
