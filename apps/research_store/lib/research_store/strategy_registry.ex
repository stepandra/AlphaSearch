defmodule ResearchStore.StrategyRegistry do
  @moduledoc """
  Explicit persistence boundary for strategy extraction runs, formulas, specs, and validation results.
  """

  import Ecto.Query

  alias ResearchCore.Strategy.{
    DataRequirement,
    EvidenceLink,
    ExecutionAssumption,
    ExtractionRun,
    FeatureRequirement,
    FormulaCandidate,
    MetricHint,
    StrategySpec,
    ValidationHint,
    ValidationResult
  }

  alias ResearchStore.{ArtifactId, Json, Repo}
  alias ResearchStore.Artifacts.StrategyExtractionRun, as: RunSchema
  alias ResearchStore.Artifacts.StrategyFormulaCandidate, as: FormulaSchema
  alias ResearchStore.Artifacts.StrategySpec, as: StrategySpecSchema
  alias ResearchStore.Artifacts.StrategyValidationResult, as: ValidationSchema

  @spec create_run(ExtractionRun.t()) :: {:ok, ExtractionRun.t()} | {:error, term()}
  def create_run(%ExtractionRun{} = run) do
    attrs = %{
      id: run.id,
      corpus_snapshot_id: run.corpus_snapshot_id,
      synthesis_run_id: run.synthesis_run_id,
      synthesis_artifact_id: run.synthesis_artifact_id,
      normalized_theme_id: run.normalized_theme_id,
      research_branch_id: run.research_branch_id,
      synthesis_profile_id: run.synthesis_profile_id,
      state: Atom.to_string(run.state),
      input_package: Json.normalize(run.input_package || %{}),
      formula_request_spec: Json.normalize(run.formula_request_spec || %{}),
      strategy_request_spec: Json.normalize(run.strategy_request_spec || %{}),
      provider_name: run.provider_name,
      provider_model: run.provider_model,
      provider_request_id: run.provider_request_id,
      provider_response_id: run.provider_response_id,
      provider_request_hash: run.provider_request_hash,
      provider_response_hash: run.provider_response_hash,
      provider_metadata: Json.normalize(run.provider_metadata || %{}),
      provider_failure: Json.normalize(run.provider_failure || %{}),
      raw_provider_output: Json.normalize(run.raw_provider_output || %{}),
      started_at: run.started_at,
      completed_at: run.completed_at
    }

    case Repo.insert(RunSchema.changeset(%RunSchema{}, attrs)) do
      {:ok, _schema} -> {:ok, get_run!(run.id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec update_run(String.t(), map()) :: {:ok, ExtractionRun.t()} | {:error, term()}
  def update_run(run_id, attrs) when is_binary(run_id) and is_map(attrs) do
    with %RunSchema{} = run <- Repo.get(RunSchema, run_id) do
      run
      |> RunSchema.changeset(normalize_run_attrs(attrs))
      |> Repo.update()
      |> case do
        {:ok, _updated} -> {:ok, get_run!(run_id)}
        {:error, reason} -> {:error, reason}
      end
    else
      nil -> {:error, {:missing_strategy_extraction_run, run_id}}
    end
  end

  @spec put_validation_result(String.t(), ValidationResult.t()) ::
          {:ok, ValidationResult.t()} | {:error, term()}
  def put_validation_result(run_id, %ValidationResult{} = validation_result) do
    attrs = %{
      id: validation_result.id || ArtifactId.build("strategy_validation", %{run_id: run_id}),
      strategy_extraction_run_id: run_id,
      valid: validation_result.valid?,
      fatal_errors: Json.normalize(validation_result.fatal_errors),
      warnings: Json.normalize(validation_result.warnings),
      rejected_formulas: Json.normalize(validation_result.rejected_formulas),
      rejected_candidates: Json.normalize(validation_result.rejected_candidates),
      duplicate_groups: Json.normalize(validation_result.duplicate_groups),
      accepted_formula_ids: validation_result.accepted_formula_ids,
      accepted_strategy_ids: validation_result.accepted_strategy_ids,
      validated_at: validation_result.validated_at
    }

    case Repo.insert(
           ValidationSchema.changeset(%ValidationSchema{}, attrs),
           on_conflict: [set: Map.to_list(Map.delete(attrs, :id))],
           conflict_target: :strategy_extraction_run_id
         ) do
      {:ok, _schema} -> {:ok, validation_result_for_run!(run_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec replace_formulas(String.t(), [FormulaCandidate.t()]) ::
          {:ok, [FormulaCandidate.t()]} | {:error, term()}
  def replace_formulas(run_id, formulas) when is_binary(run_id) and is_list(formulas) do
    Repo.transaction(fn ->
      Repo.delete_all(
        from(formula in FormulaSchema, where: formula.strategy_extraction_run_id == ^run_id)
      )

      Enum.each(formulas, fn %FormulaCandidate{} = formula ->
        attrs = %{
          id: formula.id,
          strategy_extraction_run_id: run_id,
          corpus_snapshot_id: run_snapshot_id(run_id),
          synthesis_artifact_id: run_artifact_id(run_id),
          formula_text: formula.formula_text,
          exact: formula.exact?,
          partial: formula.partial?,
          blocked: formula.blocked?,
          role: Atom.to_string(formula.role),
          symbol_glossary: Json.normalize(formula.symbol_glossary),
          source_section_ids: Enum.map(formula.source_section_ids, &Atom.to_string/1),
          source_section_headings: formula.source_section_headings,
          supporting_citation_keys: formula.supporting_citation_keys,
          supporting_record_ids: formula.supporting_record_ids,
          evidence_links: Json.normalize(formula.evidence_links),
          notes: Json.normalize(formula.notes)
        }

        case Repo.insert(FormulaSchema.changeset(%FormulaSchema{}, attrs)) do
          {:ok, _schema} -> :ok
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

      list_formulas_for_run(run_id)
    end)
    |> unwrap_transaction()
  end

  @spec replace_strategy_specs(String.t(), [StrategySpec.t()]) ::
          {:ok, [StrategySpec.t()]} | {:error, term()}
  def replace_strategy_specs(run_id, strategy_specs)
      when is_binary(run_id) and is_list(strategy_specs) do
    Repo.transaction(fn ->
      Repo.delete_all(
        from(spec in StrategySpecSchema, where: spec.strategy_extraction_run_id == ^run_id)
      )

      Enum.each(strategy_specs, fn %StrategySpec{} = strategy_spec ->
        attrs = %{
          id: strategy_spec.id,
          strategy_extraction_run_id: run_id,
          corpus_snapshot_id: strategy_spec.corpus_snapshot_id,
          synthesis_run_id: strategy_spec.synthesis_run_id,
          synthesis_artifact_id: strategy_spec.synthesis_artifact_id,
          strategy_candidate_id: strategy_spec.strategy_candidate_id,
          title: strategy_spec.title,
          thesis: strategy_spec.thesis,
          category: Atom.to_string(strategy_spec.category),
          candidate_kind: Atom.to_string(strategy_spec.candidate_kind),
          market_or_domain_applicability: strategy_spec.market_or_domain_applicability,
          decision_rule: Json.normalize(strategy_spec.decision_rule),
          expected_edge_source: strategy_spec.expected_edge_source,
          falsification_idea: strategy_spec.falsification_idea,
          readiness: Atom.to_string(strategy_spec.readiness),
          evidence_strength: Atom.to_string(strategy_spec.evidence_strength),
          actionability: Atom.to_string(strategy_spec.actionability),
          formula_ids: strategy_spec.formula_ids,
          required_features: Json.normalize(strategy_spec.required_features),
          required_datasets: Json.normalize(strategy_spec.required_datasets),
          execution_assumptions: Json.normalize(strategy_spec.execution_assumptions),
          sizing_assumptions: Json.normalize(strategy_spec.sizing_assumptions),
          evidence_links: Json.normalize(strategy_spec.evidence_links),
          conflicting_evidence_links: Json.normalize(strategy_spec.conflicting_evidence_links),
          validation_hints: Json.normalize(strategy_spec.validation_hints),
          metric_hints: Json.normalize(strategy_spec.metric_hints),
          notes: Json.normalize(strategy_spec.notes),
          blocked_by: strategy_spec.blocked_by
        }

        case Repo.insert(StrategySpecSchema.changeset(%StrategySpecSchema{}, attrs)) do
          {:ok, _schema} -> :ok
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

      list_strategy_specs_for_run(run_id)
    end)
    |> unwrap_transaction()
  end

  @spec get_run(String.t()) :: ExtractionRun.t() | nil
  def get_run(run_id) do
    RunSchema
    |> Repo.get(run_id)
    |> maybe_preload_run()
    |> maybe_to_run()
  end

  @spec get_run!(String.t()) :: ExtractionRun.t()
  def get_run!(run_id) do
    case get_run(run_id) do
      nil -> raise ArgumentError, "missing strategy extraction run #{run_id}"
      run -> run
    end
  end

  @spec latest_run_for_snapshot(String.t(), String.t()) :: ExtractionRun.t() | nil
  def latest_run_for_snapshot(snapshot_id, synthesis_profile_id) do
    Repo.one(
      from(run in RunSchema,
        where:
          run.corpus_snapshot_id == ^snapshot_id and
            run.synthesis_profile_id == ^synthesis_profile_id,
        order_by: [desc: run.inserted_at],
        limit: 1
      )
    )
    |> maybe_preload_run()
    |> maybe_to_run()
  end

  @spec validation_failures(String.t()) :: ValidationResult.t() | nil
  def validation_failures(run_id) do
    Repo.one(
      from(validation in ValidationSchema,
        where: validation.strategy_extraction_run_id == ^run_id and validation.valid == false,
        limit: 1
      )
    )
    |> maybe_to_validation_result()
  end

  @spec list_formulas_for_run(String.t()) :: [FormulaCandidate.t()]
  def list_formulas_for_run(run_id) do
    Repo.all(
      from(formula in FormulaSchema,
        where: formula.strategy_extraction_run_id == ^run_id,
        order_by: [asc: formula.inserted_at, asc: formula.id]
      )
    )
    |> Enum.map(&to_formula/1)
  end

  @spec list_strategy_specs_for_run(String.t()) :: [StrategySpec.t()]
  def list_strategy_specs_for_run(run_id) do
    Repo.all(
      from(spec in StrategySpecSchema,
        where: spec.strategy_extraction_run_id == ^run_id,
        order_by: [asc: spec.inserted_at, asc: spec.id]
      )
    )
    |> Enum.map(&to_strategy_spec/1)
  end

  @spec list_specs_for_snapshot(String.t(), keyword()) :: [StrategySpec.t()]
  def list_specs_for_snapshot(snapshot_id, opts \\ []) do
    Repo.all(
      StrategySpecSchema
      |> join(:inner, [spec], run in RunSchema, on: run.id == spec.strategy_extraction_run_id)
      |> where([spec, run], spec.corpus_snapshot_id == ^snapshot_id and run.state == "completed")
      |> apply_spec_filters(opts)
      |> select([spec, _run], spec)
    )
    |> Enum.map(&to_strategy_spec/1)
  end

  @spec ready_specs_for_snapshot(String.t(), keyword()) :: [StrategySpec.t()]
  def ready_specs_for_snapshot(snapshot_id, opts \\ []) do
    list_specs_for_snapshot(snapshot_id, Keyword.put(opts, :readiness, :ready_for_backtest))
  end

  @spec list_specs_for_artifact(String.t(), keyword()) :: [StrategySpec.t()]
  def list_specs_for_artifact(artifact_id, opts \\ []) do
    Repo.all(
      StrategySpecSchema
      |> join(:inner, [spec], run in RunSchema, on: run.id == spec.strategy_extraction_run_id)
      |> where(
        [spec, run],
        spec.synthesis_artifact_id == ^artifact_id and run.state == "completed"
      )
      |> apply_spec_filters(opts)
      |> select([spec, _run], spec)
    )
    |> Enum.map(&to_strategy_spec/1)
  end

  @spec list_specs_for_branch(String.t(), keyword()) :: [StrategySpec.t()]
  def list_specs_for_branch(branch_id, opts \\ []) do
    Repo.all(
      StrategySpecSchema
      |> join(:inner, [spec], run in RunSchema, on: run.id == spec.strategy_extraction_run_id)
      |> where([spec, run], run.research_branch_id == ^branch_id and run.state == "completed")
      |> apply_spec_filters(opts)
      |> select([spec, _run], spec)
    )
    |> Enum.map(&to_strategy_spec/1)
  end

  @spec list_specs_for_theme(String.t(), keyword()) :: [StrategySpec.t()]
  def list_specs_for_theme(theme_id, opts \\ []) do
    Repo.all(
      StrategySpecSchema
      |> join(:inner, [spec], run in RunSchema, on: run.id == spec.strategy_extraction_run_id)
      |> where([spec, run], run.normalized_theme_id == ^theme_id and run.state == "completed")
      |> apply_spec_filters(opts)
      |> select([spec, _run], spec)
    )
    |> Enum.map(&to_strategy_spec/1)
  end

  @spec latest_specs_for_branch(String.t(), keyword()) :: [StrategySpec.t()]
  def latest_specs_for_branch(branch_id, opts \\ []) do
    case latest_run_id_for_context(:research_branch_id, branch_id, opts) do
      nil -> []
      run_id -> list_specs_for_run_with_filters(run_id, opts)
    end
  end

  @spec latest_specs_for_theme(String.t(), keyword()) :: [StrategySpec.t()]
  def latest_specs_for_theme(theme_id, opts \\ []) do
    case latest_run_id_for_context(:normalized_theme_id, theme_id, opts) do
      nil -> []
      run_id -> list_specs_for_run_with_filters(run_id, opts)
    end
  end

  @spec list_formulas_for_spec(String.t()) :: [FormulaCandidate.t()]
  def list_formulas_for_spec(spec_id) do
    case Repo.get(StrategySpecSchema, spec_id) do
      nil ->
        []

      %StrategySpecSchema{} = spec ->
        formula_lookup =
          Repo.all(
            from(formula in FormulaSchema,
              where:
                formula.strategy_extraction_run_id == ^spec.strategy_extraction_run_id and
                  formula.id in ^spec.formula_ids
            )
          )
          |> Enum.map(&to_formula/1)
          |> Map.new(&{&1.id, &1})

        Enum.flat_map(spec.formula_ids, fn formula_id ->
          case Map.get(formula_lookup, formula_id) do
            nil -> []
            formula -> [formula]
          end
        end)
    end
  end

  @spec get_spec_with_provenance(String.t()) ::
          %{spec: StrategySpec.t(), formulas: [FormulaCandidate.t()]} | nil
  def get_spec_with_provenance(spec_id) do
    case Repo.get(StrategySpecSchema, spec_id) do
      nil ->
        nil

      %StrategySpecSchema{} = spec ->
        %{
          spec: to_strategy_spec(spec),
          formulas: list_formulas_for_spec(spec_id)
        }
    end
  end

  defp apply_spec_filters(query, opts) do
    query
    |> maybe_filter(:category, Keyword.get(opts, :category))
    |> maybe_filter(:readiness, Keyword.get(opts, :readiness))
    |> maybe_filter(:actionability, Keyword.get(opts, :actionability))
    |> order_by([spec], asc: spec.title, asc: spec.id)
  end

  defp maybe_filter(query, _field, nil), do: query

  defp maybe_filter(query, field, value) when is_atom(value) do
    maybe_filter(query, field, Atom.to_string(value))
  end

  defp maybe_filter(query, field, value) do
    from(spec in query, where: field(spec, ^field) == ^value)
  end

  defp latest_run_id_for_context(field, value, opts) do
    query =
      from(run in RunSchema,
        where: field(run, ^field) == ^value and run.state == "completed",
        order_by: [desc: run.completed_at, desc: run.inserted_at],
        limit: 1,
        select: run.id
      )

    query =
      case Keyword.get(opts, :synthesis_profile_id) do
        profile_id when is_binary(profile_id) ->
          from(run in query, where: run.synthesis_profile_id == ^profile_id)

        _ ->
          query
      end

    Repo.one(query)
  end

  defp list_specs_for_run_with_filters(run_id, opts) do
    Repo.all(
      StrategySpecSchema
      |> where([spec], spec.strategy_extraction_run_id == ^run_id)
      |> apply_spec_filters(opts)
    )
    |> Enum.map(&to_strategy_spec/1)
  end

  defp maybe_preload_run(nil), do: nil

  defp maybe_preload_run(run),
    do: Repo.preload(run, [:validation_result, :formulas, :strategy_specs])

  defp maybe_to_run(nil), do: nil
  defp maybe_to_run(run), do: to_run(run)

  defp maybe_to_validation_result(nil), do: nil
  defp maybe_to_validation_result(validation), do: to_validation_result(validation)

  defp to_run(%RunSchema{} = run) do
    %ExtractionRun{
      id: run.id,
      corpus_snapshot_id: run.corpus_snapshot_id,
      synthesis_run_id: run.synthesis_run_id,
      synthesis_artifact_id: run.synthesis_artifact_id,
      synthesis_profile_id: run.synthesis_profile_id,
      normalized_theme_id: run.normalized_theme_id,
      research_branch_id: run.research_branch_id,
      state: String.to_existing_atom(run.state),
      input_package: run.input_package,
      formula_request_spec: run.formula_request_spec,
      strategy_request_spec: run.strategy_request_spec,
      provider_name: run.provider_name,
      provider_model: run.provider_model,
      provider_request_id: run.provider_request_id,
      provider_response_id: run.provider_response_id,
      provider_request_hash: run.provider_request_hash,
      provider_response_hash: run.provider_response_hash,
      provider_metadata: run.provider_metadata,
      provider_failure: provider_failure_from_map(run.provider_failure),
      raw_provider_output: run.raw_provider_output,
      started_at: run.started_at,
      completed_at: run.completed_at,
      validation_result: maybe_loaded_validation(run.validation_result),
      formulas: maybe_loaded_formulas(run.formulas),
      strategy_specs: maybe_loaded_specs(run.strategy_specs)
    }
  end

  defp to_validation_result(%ValidationSchema{} = validation) do
    %ValidationResult{
      id: validation.id,
      strategy_extraction_run_id: validation.strategy_extraction_run_id,
      valid?: validation.valid,
      fatal_errors: Enum.map(validation.fatal_errors, &normalize_issue/1),
      warnings: Enum.map(validation.warnings, &normalize_issue/1),
      rejected_formulas: validation.rejected_formulas,
      rejected_candidates: validation.rejected_candidates,
      duplicate_groups: validation.duplicate_groups,
      accepted_formula_ids: validation.accepted_formula_ids,
      accepted_strategy_ids: validation.accepted_strategy_ids,
      validated_at: validation.validated_at
    }
  end

  defp to_formula(%FormulaSchema{} = formula) do
    %FormulaCandidate{
      id: formula.id,
      formula_text: formula.formula_text,
      exact?: formula.exact,
      partial?: formula.partial,
      blocked?: formula.blocked,
      role: String.to_existing_atom(formula.role),
      symbol_glossary: formula.symbol_glossary,
      source_section_ids: Enum.map(formula.source_section_ids, &String.to_existing_atom/1),
      source_section_headings: formula.source_section_headings,
      supporting_citation_keys: formula.supporting_citation_keys,
      supporting_record_ids: formula.supporting_record_ids,
      evidence_links: Enum.map(List.wrap(formula.evidence_links), &to_evidence_link/1),
      notes: List.wrap(formula.notes)
    }
  end

  defp to_strategy_spec(%StrategySpecSchema{} = strategy_spec) do
    %StrategySpec{
      id: strategy_spec.id,
      strategy_candidate_id: strategy_spec.strategy_candidate_id,
      strategy_extraction_run_id: strategy_spec.strategy_extraction_run_id,
      corpus_snapshot_id: strategy_spec.corpus_snapshot_id,
      synthesis_run_id: strategy_spec.synthesis_run_id,
      synthesis_artifact_id: strategy_spec.synthesis_artifact_id,
      title: strategy_spec.title,
      thesis: strategy_spec.thesis,
      category: String.to_existing_atom(strategy_spec.category),
      candidate_kind: String.to_existing_atom(strategy_spec.candidate_kind),
      market_or_domain_applicability: strategy_spec.market_or_domain_applicability,
      decision_rule: strategy_spec.decision_rule,
      expected_edge_source: strategy_spec.expected_edge_source,
      falsification_idea: strategy_spec.falsification_idea,
      readiness: String.to_existing_atom(strategy_spec.readiness),
      evidence_strength: String.to_existing_atom(strategy_spec.evidence_strength),
      actionability: String.to_existing_atom(strategy_spec.actionability),
      formula_ids: strategy_spec.formula_ids,
      required_features:
        Enum.map(List.wrap(strategy_spec.required_features), &to_feature_requirement/1),
      required_datasets:
        Enum.map(List.wrap(strategy_spec.required_datasets), &to_data_requirement/1),
      execution_assumptions:
        Enum.map(List.wrap(strategy_spec.execution_assumptions), &to_execution_assumption/1),
      sizing_assumptions:
        Enum.map(List.wrap(strategy_spec.sizing_assumptions), &to_execution_assumption/1),
      evidence_links: Enum.map(List.wrap(strategy_spec.evidence_links), &to_evidence_link/1),
      conflicting_evidence_links:
        Enum.map(List.wrap(strategy_spec.conflicting_evidence_links), &to_evidence_link/1),
      validation_hints:
        Enum.map(List.wrap(strategy_spec.validation_hints), &to_validation_hint/1),
      metric_hints: Enum.map(List.wrap(strategy_spec.metric_hints), &to_metric_hint/1),
      notes: List.wrap(strategy_spec.notes),
      blocked_by: strategy_spec.blocked_by
    }
  end

  defp to_feature_requirement(%{} = value) do
    %FeatureRequirement{
      name: value["name"] || value[:name],
      description: value["description"] || value[:description],
      status: atom_field(value, "status"),
      source: value["source"] || value[:source],
      citation_keys: value["citation_keys"] || value[:citation_keys] || []
    }
  end

  defp to_data_requirement(%{} = value) do
    %DataRequirement{
      name: value["name"] || value[:name],
      description: value["description"] || value[:description],
      mapping_status: atom_field(value, "mapping_status"),
      source: value["source"] || value[:source],
      citation_keys: value["citation_keys"] || value[:citation_keys] || []
    }
  end

  defp to_execution_assumption(%{} = value) do
    %ExecutionAssumption{
      kind: atom_field(value, "kind"),
      description: value["description"] || value[:description],
      blocking?: value["blocking?"] || value[:blocking?] || false,
      citation_keys: value["citation_keys"] || value[:citation_keys] || []
    }
  end

  defp to_validation_hint(%{} = value) do
    %ValidationHint{
      kind: atom_field(value, "kind"),
      description: value["description"] || value[:description],
      priority: atom_field(value, "priority"),
      blockers: value["blockers"] || value[:blockers] || []
    }
  end

  defp to_metric_hint(%{} = value) do
    %MetricHint{
      name: value["name"] || value[:name],
      description: value["description"] || value[:description],
      direction: atom_field(value, "direction")
    }
  end

  defp to_evidence_link(%{} = value) do
    %EvidenceLink{
      section_id: atom_field(value, "section_id"),
      section_heading: value["section_heading"] || value[:section_heading],
      citation_key: value["citation_key"] || value[:citation_key],
      record_id: value["record_id"] || value[:record_id],
      relation: atom_field(value, "relation"),
      quote: value["quote"] || value[:quote],
      note: value["note"] || value[:note],
      provenance_reference: value["provenance_reference"] || value[:provenance_reference] || %{}
    }
  end

  defp maybe_loaded_validation(%Ecto.Association.NotLoaded{}), do: nil
  defp maybe_loaded_validation(nil), do: nil
  defp maybe_loaded_validation(validation), do: to_validation_result(validation)

  defp maybe_loaded_formulas(%Ecto.Association.NotLoaded{}), do: []
  defp maybe_loaded_formulas(formulas), do: Enum.map(formulas, &to_formula/1)

  defp maybe_loaded_specs(%Ecto.Association.NotLoaded{}), do: []
  defp maybe_loaded_specs(specs), do: Enum.map(specs, &to_strategy_spec/1)

  defp validation_result_for_run!(run_id) do
    Repo.one!(
      from(validation in ValidationSchema,
        where: validation.strategy_extraction_run_id == ^run_id
      )
    )
    |> to_validation_result()
  end

  defp run_snapshot_id(run_id) do
    Repo.one!(from(run in RunSchema, where: run.id == ^run_id, select: run.corpus_snapshot_id))
  end

  defp run_artifact_id(run_id) do
    Repo.one!(from(run in RunSchema, where: run.id == ^run_id, select: run.synthesis_artifact_id))
  end

  defp normalize_run_attrs(attrs) do
    attrs
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case key do
        :state ->
          Map.put(acc, :state, Atom.to_string(value))

        :input_package ->
          Map.put(acc, :input_package, Json.normalize(value || %{}))

        :formula_request_spec ->
          Map.put(acc, :formula_request_spec, Json.normalize(value || %{}))

        :strategy_request_spec ->
          Map.put(acc, :strategy_request_spec, Json.normalize(value || %{}))

        :provider_metadata ->
          Map.put(acc, :provider_metadata, Json.normalize(value || %{}))

        :provider_failure ->
          Map.put(acc, :provider_failure, Json.normalize(value || %{}))

        :raw_provider_output ->
          Map.put(acc, :raw_provider_output, Json.normalize(value || %{}))

        _ ->
          Map.put(acc, key, value)
      end
    end)
  end

  defp provider_failure_from_map(%{} = value) when map_size(value) == 0, do: nil

  defp provider_failure_from_map(%{} = value) do
    %{
      provider: lookup_field(value, "provider"),
      reason: lookup_field(value, "reason"),
      message: lookup_field(value, "message"),
      details: lookup_field(value, "details") || %{},
      retryable?: truthy?(lookup_field(value, "retryable?"))
    }
  end

  defp provider_failure_from_map(value), do: value

  defp normalize_issue(%{} = issue) do
    %{
      type: atom_field(issue, "type"),
      message: lookup_field(issue, "message"),
      severity: atom_field(issue, "severity"),
      details: lookup_field(issue, "details") || %{}
    }
  end

  defp normalize_issue(issue), do: issue

  defp atom_field(value, key) do
    case lookup_field(value, key) do
      nil -> nil
      atom when is_atom(atom) -> atom
      string when is_binary(string) -> String.to_existing_atom(string)
    end
  end

  defp lookup_field(value, key) when is_map(value) do
    Enum.find_value(value, fn {field_key, field_value} ->
      if to_string(field_key) == key do
        field_value
      end
    end)
  end

  defp lookup_field(_value, _key), do: nil

  defp truthy?(value), do: value in [true, "true", 1, "1"]

  defp unwrap_transaction({:ok, value}), do: {:ok, value}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
end
