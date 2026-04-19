defmodule ResearchStore.Themes do
  @moduledoc """
  Persistence boundary for raw and normalized research themes.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias ResearchCore.Theme.{Constraint, DomainHint, MechanismHint, Normalized, Objective, Raw}
  alias ResearchStore.{ArtifactId, Repo}
  alias ResearchStore.Artifacts.{NormalizedTheme, ResearchTheme}

  @spec store_theme(Raw.t(), Normalized.t()) ::
          {:ok, %{theme: ResearchTheme.t(), normalized_theme: NormalizedTheme.t()}}
          | {:error, Ecto.Changeset.t() | term()}
  def store_theme(%Raw{} = raw_theme, %Normalized{} = normalized_theme) do
    theme_id = theme_id(raw_theme)
    normalized_theme_id = normalized_theme_id(normalized_theme)

    Multi.new()
    |> Multi.insert(
      :theme,
      ResearchTheme.changeset(%ResearchTheme{}, %{
        id: theme_id,
        raw_text: raw_theme.raw_text,
        source: raw_theme.source,
        content_hash:
          ArtifactId.fingerprint(raw_theme.raw_text <> "|" <> to_string(raw_theme.source))
      }),
      on_conflict: :nothing,
      conflict_target: :id
    )
    |> Multi.run(:persisted_theme, fn repo, _changes ->
      fetch_required(repo, ResearchTheme, theme_id)
    end)
    |> Multi.insert(
      :normalized_theme,
      NormalizedTheme.changeset(%NormalizedTheme{}, %{
        id: normalized_theme_id,
        research_theme_id: theme_id,
        original_input: normalized_theme.original_input,
        normalized_text: normalized_theme.normalized_text,
        topic: normalized_theme.topic,
        objective_description: objective_description(normalized_theme.objective),
        notes: normalized_theme.notes,
        domain_hints: Enum.map(normalized_theme.domain_hints, & &1.label),
        mechanism_hints: Enum.map(normalized_theme.mechanism_hints, & &1.label),
        constraints: Enum.map(normalized_theme.constraints, &constraint_to_map/1)
      }),
      on_conflict: :nothing,
      conflict_target: :id
    )
    |> Multi.run(:persisted_normalized_theme, fn repo, _changes ->
      fetch_required(repo, NormalizedTheme, normalized_theme_id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{persisted_theme: theme, persisted_normalized_theme: normalized}} ->
        {:ok, %{theme: theme, normalized_theme: normalized}}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  @spec get_normalized_theme(String.t()) :: NormalizedTheme.t() | nil
  def get_normalized_theme(id), do: Repo.get(NormalizedTheme, id)

  @spec list_normalized_themes() :: [NormalizedTheme.t()]
  def list_normalized_themes do
    Repo.all(from(theme in NormalizedTheme, order_by: [desc: theme.inserted_at]))
  end

  @spec theme_id(Raw.t()) :: String.t()
  def theme_id(%Raw{} = raw_theme) do
    ArtifactId.build("theme", %{raw_text: raw_theme.raw_text, source: raw_theme.source})
  end

  @spec normalized_theme_id(Normalized.t()) :: String.t()
  def normalized_theme_id(%Normalized{} = normalized_theme) do
    ArtifactId.build("normalized_theme", %{
      original_input: normalized_theme.original_input,
      normalized_text: normalized_theme.normalized_text,
      topic: normalized_theme.topic,
      objective: objective_description(normalized_theme.objective),
      notes: normalized_theme.notes,
      domain_hints: Enum.map(normalized_theme.domain_hints, & &1.label),
      mechanism_hints: Enum.map(normalized_theme.mechanism_hints, & &1.label),
      constraints: Enum.map(normalized_theme.constraints, &constraint_to_map/1)
    })
  end

  @spec to_core(NormalizedTheme.t()) :: Normalized.t()
  def to_core(%NormalizedTheme{} = theme) do
    %Normalized{
      original_input: theme.original_input,
      normalized_text: theme.normalized_text,
      topic: theme.topic,
      objective: objective_from_string(theme.objective_description),
      notes: theme.notes,
      domain_hints: Enum.map(theme.domain_hints, &%DomainHint{label: &1}),
      mechanism_hints: Enum.map(theme.mechanism_hints, &%MechanismHint{label: &1}),
      constraints: Enum.map(theme.constraints, &constraint_from_map/1)
    }
  end

  defp fetch_required(repo, schema, id) do
    case repo.get(schema, id) do
      nil -> {:error, {:missing_record, schema, id}}
      record -> {:ok, record}
    end
  end

  defp objective_description(%Objective{description: description}), do: description
  defp objective_description(nil), do: nil

  defp objective_from_string(nil), do: nil
  defp objective_from_string(description), do: %Objective{description: description}

  defp constraint_to_map(%Constraint{} = constraint) do
    %{
      description: constraint.description,
      kind: constraint.kind && Atom.to_string(constraint.kind)
    }
  end

  defp constraint_from_map(%{"description" => description, "kind" => kind}) do
    %Constraint{description: description, kind: kind && String.to_atom(kind)}
  end

  defp constraint_from_map(%{description: description, kind: kind}) do
    %Constraint{description: description, kind: kind && String.to_atom(kind)}
  end
end
