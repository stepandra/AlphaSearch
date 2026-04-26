defmodule ResearchCore.Strategy.Validator do
  @moduledoc """
  Validation guardrails for normalized formulas and strategy specs.
  """

  alias ResearchCore.Strategy.ValidationResult

  @spec validate(list(), list(), [map()], [map()], [map()]) :: ValidationResult.t()
  def validate(formulas, specs, rejected_formulas, rejected_candidates, duplicate_groups) do
    rejection_issues = Enum.map(rejected_formulas ++ rejected_candidates, &issue(&1))
    spec_readiness_issues = spec_readiness_issues(specs)
    empty_result_issues = empty_result_issues(formulas, specs)
    duplicate_warnings = duplicate_warnings(duplicate_groups)

    fatal_errors =
      rejection_issues
      |> Enum.concat(spec_readiness_issues)
      |> Enum.concat(empty_result_issues)
      |> Enum.filter(&(&1.severity == :fatal))

    warnings =
      rejection_issues
      |> Enum.concat(spec_readiness_issues)
      |> Enum.concat(empty_result_issues)
      |> Enum.filter(&(&1.severity != :fatal))
      |> Enum.concat(duplicate_warnings)

    %ValidationResult{
      valid?: fatal_errors == [],
      fatal_errors: fatal_errors,
      warnings: warnings,
      rejected_formulas: rejected_formulas,
      rejected_candidates: rejected_candidates,
      duplicate_groups: duplicate_groups,
      accepted_formula_ids: Enum.map(formulas, & &1.id),
      accepted_strategy_ids: Enum.map(specs, & &1.id),
      validated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    }
  end

  defp issue(rejection) do
    severity = Map.get(rejection, :severity, :warning)
    details = Map.get(rejection, :details, %{})

    %{
      type: Map.get(rejection, :type),
      message: Map.get(rejection, :message),
      severity: severity,
      details: details
    }
  end

  defp duplicate_warnings(duplicate_groups) do
    Enum.map(duplicate_groups, fn duplicate_group ->
      %{
        type: :duplicate_candidate_group,
        message: "merged duplicate candidates into #{duplicate_group.canonical_candidate_id}",
        severity: :warning,
        details: duplicate_group
      }
    end)
  end

  defp spec_readiness_issues(specs) do
    Enum.flat_map(specs, fn spec ->
      if spec.readiness == :reject do
        [
          %{
            type: :rejected_strategy_spec,
            message: "strategy spec #{spec.id} is marked reject",
            severity: :fatal,
            details: %{strategy_spec_id: spec.id}
          }
        ]
      else
        []
      end
    end)
  end

  defp empty_result_issues(formulas, specs) do
    []
    |> maybe_add_empty_issue(
      formulas,
      :no_accepted_formulas,
      "strategy extraction accepted no formulas"
    )
    |> maybe_add_empty_issue(
      specs,
      :no_accepted_strategy_specs,
      "strategy extraction accepted no strategy specs"
    )
  end

  defp maybe_add_empty_issue(issues, values, _type, _message) when values != [], do: issues

  defp maybe_add_empty_issue(issues, _values, type, message) do
    issues ++
      [
        %{
          type: type,
          message: message,
          severity: :fatal,
          details: %{}
        }
      ]
  end
end
