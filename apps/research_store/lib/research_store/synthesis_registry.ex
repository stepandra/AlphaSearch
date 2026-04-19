defmodule ResearchStore.SynthesisRegistry do
  @moduledoc """
  Explicit persistence boundary for synthesis runs, validation results, and report artifacts.
  """

  import Ecto.Query

  alias ResearchCore.Synthesis.{Artifact, Run, ValidationResult}
  alias ResearchStore.{ArtifactId, Json, Repo}
  alias ResearchStore.Artifacts.SynthesisArtifact, as: ArtifactSchema
  alias ResearchStore.Artifacts.SynthesisRun, as: RunSchema
  alias ResearchStore.Artifacts.SynthesisValidationResult, as: ValidationSchema

  @spec create_run(Run.t()) :: {:ok, Run.t()} | {:error, term()}
  def create_run(%Run{} = run) do
    attrs = %{
      id: run.id,
      corpus_snapshot_id: run.corpus_snapshot_id,
      normalized_theme_id: run.normalized_theme_id,
      research_branch_id: run.research_branch_id,
      profile_id: run.profile_id,
      state: Atom.to_string(run.state),
      input_package: Json.normalize(run.input_package || %{}),
      request_spec: Json.normalize(run.request_spec || %{}),
      provider_name: run.provider_name,
      provider_model: run.provider_model,
      provider_request_id: run.provider_request_id,
      provider_response_id: run.provider_response_id,
      provider_request_hash: run.provider_request_hash,
      provider_response_hash: run.provider_response_hash,
      provider_metadata: Json.normalize(run.provider_metadata || %{}),
      provider_failure: Json.normalize(run.provider_failure || %{}),
      raw_provider_output: run.raw_provider_output,
      started_at: run.started_at,
      completed_at: run.completed_at
    }

    case Repo.insert(RunSchema.changeset(%RunSchema{}, attrs)) do
      {:ok, _schema} -> {:ok, get_run!(run.id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec update_run(String.t(), map()) :: {:ok, Run.t()} | {:error, term()}
  def update_run(run_id, attrs) when is_binary(run_id) and is_map(attrs) do
    with %RunSchema{} = run <- Repo.get(RunSchema, run_id) do
      attrs = normalize_run_attrs(attrs)

      run
      |> RunSchema.changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, _updated} -> {:ok, get_run!(run_id)}
        {:error, reason} -> {:error, reason}
      end
    else
      nil -> {:error, {:missing_synthesis_run, run_id}}
    end
  end

  @spec put_validation_result(String.t(), ValidationResult.t()) ::
          {:ok, ValidationResult.t()} | {:error, term()}
  def put_validation_result(run_id, %ValidationResult{} = validation_result) do
    attrs = %{
      id: validation_result.id || ArtifactId.build("synthesis_validation", %{run_id: run_id}),
      synthesis_run_id: run_id,
      valid: validation_result.valid?,
      structural_errors: Json.normalize(validation_result.structural_errors),
      citation_errors: Json.normalize(validation_result.citation_errors),
      formula_errors: Json.normalize(validation_result.formula_errors),
      cited_keys: validation_result.cited_keys,
      allowed_keys: validation_result.allowed_keys,
      unknown_keys: validation_result.unknown_keys,
      metadata: Json.normalize(validation_result.metadata || %{}),
      validated_at: validation_result.validated_at
    }

    case Repo.insert(
           ValidationSchema.changeset(%ValidationSchema{}, attrs),
           on_conflict: [set: Map.to_list(Map.delete(attrs, :id))],
           conflict_target: :synthesis_run_id
         ) do
      {:ok, _schema} ->
        {:ok, validation_result_for_run!(run_id)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec put_artifact(Artifact.t()) :: {:ok, Artifact.t()} | {:error, term()}
  def put_artifact(%Artifact{} = artifact) do
    attrs = %{
      id: artifact.id,
      synthesis_run_id: artifact.synthesis_run_id,
      corpus_snapshot_id: artifact.corpus_snapshot_id,
      profile_id: artifact.profile_id,
      format: Atom.to_string(artifact.format),
      content: artifact.content,
      section_headings: artifact.section_headings,
      cited_keys: artifact.cited_keys,
      artifact_hash: artifact.artifact_hash,
      summary: Json.normalize(artifact.summary || %{}),
      finalized_at: artifact.finalized_at
    }

    case Repo.insert(ArtifactSchema.changeset(%ArtifactSchema{}, attrs)) do
      {:ok, _schema} -> {:ok, artifact_for_run!(artifact.synthesis_run_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec latest_run_for_snapshot(String.t(), String.t()) :: Run.t() | nil
  def latest_run_for_snapshot(snapshot_id, profile_id) do
    Repo.one(
      from(run in RunSchema,
        where: run.corpus_snapshot_id == ^snapshot_id and run.profile_id == ^profile_id,
        order_by: [desc: run.inserted_at],
        limit: 1
      )
    )
    |> maybe_preload_run()
    |> maybe_to_run()
  end

  @spec get_run(String.t()) :: Run.t() | nil
  def get_run(run_id) do
    RunSchema
    |> Repo.get(run_id)
    |> maybe_preload_run()
    |> maybe_to_run()
  end

  @spec get_run!(String.t()) :: Run.t()
  def get_run!(run_id) do
    case get_run(run_id) do
      nil -> raise ArgumentError, "missing synthesis run #{run_id}"
      run -> run
    end
  end

  @spec successful_artifact_for_snapshot(String.t(), String.t()) :: Artifact.t() | nil
  def successful_artifact_for_snapshot(snapshot_id, profile_id) do
    Repo.one(
      from(artifact in ArtifactSchema,
        join: run in RunSchema,
        on: run.id == artifact.synthesis_run_id,
        where:
          artifact.corpus_snapshot_id == ^snapshot_id and artifact.profile_id == ^profile_id and
            run.state == "completed",
        order_by: [desc: artifact.finalized_at, desc: artifact.inserted_at],
        limit: 1
      )
    )
    |> maybe_to_artifact()
  end

  @spec validation_failures(String.t()) :: ValidationResult.t() | nil
  def validation_failures(run_id) do
    Repo.one(
      from(validation in ValidationSchema,
        where: validation.synthesis_run_id == ^run_id and validation.valid == false,
        limit: 1
      )
    )
    |> maybe_to_validation_result()
  end

  @spec list_reports_for_snapshot(String.t()) :: [Artifact.t()]
  def list_reports_for_snapshot(snapshot_id) do
    Repo.all(
      from(artifact in ArtifactSchema,
        join: run in RunSchema,
        on: run.id == artifact.synthesis_run_id,
        where: artifact.corpus_snapshot_id == ^snapshot_id and run.state == "completed",
        order_by: [desc: artifact.finalized_at, desc: artifact.inserted_at]
      )
    )
    |> Enum.map(&to_artifact/1)
  end

  @spec latest_report_for_branch(String.t(), String.t() | nil) :: Artifact.t() | nil
  def latest_report_for_branch(branch_id, profile_id \\ nil) do
    artifact_for_context(:research_branch_id, branch_id, profile_id)
  end

  @spec latest_report_for_theme(String.t(), String.t() | nil) :: Artifact.t() | nil
  def latest_report_for_theme(theme_id, profile_id \\ nil) do
    artifact_for_context(:normalized_theme_id, theme_id, profile_id)
  end

  defp artifact_for_context(field, value, profile_id) do
    query =
      from(artifact in ArtifactSchema,
        join: run in RunSchema,
        on: run.id == artifact.synthesis_run_id,
        where: field(run, ^field) == ^value and run.state == "completed",
        order_by: [desc: artifact.finalized_at, desc: artifact.inserted_at],
        limit: 1
      )

    query =
      if is_binary(profile_id) do
        from([artifact, run] in query, where: artifact.profile_id == ^profile_id)
      else
        query
      end

    Repo.one(query)
    |> maybe_to_artifact()
  end

  defp validation_result_for_run!(run_id) do
    Repo.one!(from(validation in ValidationSchema, where: validation.synthesis_run_id == ^run_id))
    |> to_validation_result()
  end

  defp artifact_for_run!(run_id) do
    Repo.one!(from(artifact in ArtifactSchema, where: artifact.synthesis_run_id == ^run_id))
    |> to_artifact()
  end

  defp maybe_preload_run(nil), do: nil
  defp maybe_preload_run(run), do: Repo.preload(run, [:validation_result, :artifact])

  defp maybe_to_run(nil), do: nil
  defp maybe_to_run(run), do: to_run(run)

  defp maybe_to_artifact(nil), do: nil
  defp maybe_to_artifact(artifact), do: to_artifact(artifact)

  defp maybe_to_validation_result(nil), do: nil
  defp maybe_to_validation_result(validation), do: to_validation_result(validation)

  defp to_run(%RunSchema{} = run) do
    %Run{
      id: run.id,
      corpus_snapshot_id: run.corpus_snapshot_id,
      normalized_theme_id: run.normalized_theme_id,
      research_branch_id: run.research_branch_id,
      profile_id: run.profile_id,
      state: String.to_existing_atom(run.state),
      input_package: run.input_package,
      request_spec: run.request_spec,
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
      artifact: maybe_loaded_artifact(run.artifact)
    }
  end

  defp to_validation_result(%ValidationSchema{} = validation) do
    %ValidationResult{
      id: validation.id,
      synthesis_run_id: validation.synthesis_run_id,
      valid?: validation.valid,
      structural_errors: validation.structural_errors,
      citation_errors: validation.citation_errors,
      formula_errors: validation.formula_errors,
      cited_keys: validation.cited_keys,
      allowed_keys: validation.allowed_keys,
      unknown_keys: validation.unknown_keys,
      metadata: validation.metadata,
      validated_at: validation.validated_at
    }
  end

  defp to_artifact(%ArtifactSchema{} = artifact) do
    %Artifact{
      id: artifact.id,
      synthesis_run_id: artifact.synthesis_run_id,
      corpus_snapshot_id: artifact.corpus_snapshot_id,
      profile_id: artifact.profile_id,
      format: String.to_existing_atom(artifact.format),
      content: artifact.content,
      artifact_hash: artifact.artifact_hash,
      finalized_at: artifact.finalized_at,
      section_headings: artifact.section_headings,
      cited_keys: artifact.cited_keys,
      summary: artifact.summary
    }
  end

  defp maybe_loaded_validation(%Ecto.Association.NotLoaded{}), do: nil
  defp maybe_loaded_validation(nil), do: nil
  defp maybe_loaded_validation(validation), do: to_validation_result(validation)

  defp maybe_loaded_artifact(%Ecto.Association.NotLoaded{}), do: nil
  defp maybe_loaded_artifact(nil), do: nil
  defp maybe_loaded_artifact(artifact), do: to_artifact(artifact)

  defp normalize_run_attrs(attrs) do
    attrs
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case key do
        :state -> Map.put(acc, :state, Atom.to_string(value))
        :input_package -> Map.put(acc, :input_package, Json.normalize(value || %{}))
        :request_spec -> Map.put(acc, :request_spec, Json.normalize(value || %{}))
        :provider_metadata -> Map.put(acc, :provider_metadata, Json.normalize(value || %{}))
        :provider_failure -> Map.put(acc, :provider_failure, Json.normalize(value || %{}))
        _ -> Map.put(acc, key, value)
      end
    end)
  end

  defp provider_failure_from_map(%{} = value) when map_size(value) == 0, do: nil

  defp provider_failure_from_map(%{} = value) do
    %{
      provider: value["provider"] || value[:provider],
      reason: value["reason"] || value[:reason],
      message: value["message"] || value[:message],
      details: value["details"] || value[:details] || %{},
      retryable?: value["retryable?"] || value[:retryable?] || false
    }
  end

  defp provider_failure_from_map(value), do: value
end
