defmodule ResearchCore.Strategy.Validator do
  @moduledoc """
  Validation guardrails for normalized formulas and strategy specs.
  """

  alias ResearchCore.Strategy.ValidationResult

  @spec validate(list(), list(), [map()], [map()], [map()]) :: ValidationResult.t()
  def validate(formulas, specs, rejected_formulas, rejected_candidates, duplicate_groups) do
    warnings =
      (rejected_formulas ++ rejected_candidates)
      |> Enum.map(&issue(&1, :warning))
      |> Kernel.++(
        Enum.map(duplicate_groups, fn duplicate_group ->
          %{
            type: :duplicate_candidate_group,
            message: "merged duplicate candidates into #{duplicate_group.canonical_candidate_id}",
            severity: :warning,
            details: duplicate_group
          }
        end)
      )
      |> Kernel.++(spec_readiness_warnings(specs))
      |> Kernel.++(empty_result_warnings(formulas, specs))

    %ValidationResult{
      valid?: true,
      fatal_errors: [],
      warnings: warnings,
      rejected_formulas: rejected_formulas,
      rejected_candidates: rejected_candidates,
      duplicate_groups: duplicate_groups,
      accepted_formula_ids: Enum.map(formulas, & &1.id),
      accepted_strategy_ids: Enum.map(specs, & &1.id),
      validated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    }
  end

  defp issue(rejection, severity) do
    original_severity = rejection.severity || rejection[:severity]
    details = Map.get(rejection, :details, %{})

    %{
      type: rejection.type || rejection[:type],
      message: rejection.message || rejection[:message],
      severity: severity,
      details:
        if(original_severity in [nil, severity],
          do: details,
          else: Map.put(details, :original_severity, original_severity)
        )
    }
  end

  defp spec_readiness_warnings(specs) do
    Enum.flat_map(specs, fn spec ->
      if spec.readiness == :reject do
        [
          %{
            type: :rejected_strategy_spec,
            message: "strategy spec #{spec.id} is marked reject",
            severity: :warning,
            details: %{strategy_spec_id: spec.id}
          }
        ]
      else
        []
      end
    end)
  end

  defp empty_result_warnings(formulas, specs) do
    []
    |> maybe_add_empty_warning(
      formulas,
      :no_accepted_formulas,
      "strategy extraction accepted no formulas"
    )
    |> maybe_add_empty_warning(
      specs,
      :no_accepted_strategy_specs,
      "strategy extraction accepted no strategy specs"
    )
  end

  defp maybe_add_empty_warning(warnings, values, _type, _message) when values != [], do: warnings

  defp maybe_add_empty_warning(warnings, _values, type, message) do
    warnings ++
      [
        %{
          type: type,
          message: message,
          severity: :warning,
          details: %{}
        }
      ]
  end
end
