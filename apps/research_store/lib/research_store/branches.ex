defmodule ResearchStore.Branches do
  @moduledoc """
  Persistence boundary for branches, query families, and generated queries.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias ResearchCore.Branch.{Branch, QueryFamily, SearchQuery}
  alias ResearchStore.{ArtifactId, Repo}
  alias ResearchStore.Artifacts.GeneratedQuery
  alias ResearchStore.Artifacts.NormalizedTheme
  alias ResearchStore.Artifacts.QueryFamily, as: QueryFamilyRecord
  alias ResearchStore.Artifacts.QueryFamilyQuery
  alias ResearchStore.Artifacts.ResearchBranch

  @spec store_branches(String.t(), [Branch.t()]) :: {:ok, [ResearchBranch.t()]} | {:error, term()}
  def store_branches(normalized_theme_id, branches) when is_list(branches) do
    Multi.new()
    |> Multi.run(:normalized_theme, fn repo, _changes ->
      case repo.get(NormalizedTheme, normalized_theme_id) do
        nil -> {:error, {:missing_normalized_theme, normalized_theme_id}}
        theme -> {:ok, theme}
      end
    end)
    |> then(fn multi ->
      Enum.reduce(branches, multi, fn %Branch{} = branch, acc ->
        branch_id = branch_id(normalized_theme_id, branch)

        acc
        |> Multi.insert(
          {:branch, branch_id},
          ResearchBranch.changeset(%ResearchBranch{}, %{
            id: branch_id,
            normalized_theme_id: normalized_theme_id,
            kind: Atom.to_string(branch.kind),
            label: branch.label,
            rationale: branch.rationale,
            theme_relation: branch.theme_relation,
            source_targeting_rationale: branch.source_targeting_rationale,
            preferred_source_families:
              Enum.map(branch.preferred_source_families, &Atom.to_string/1)
          }),
          on_conflict: :nothing,
          conflict_target: :id
        )
        |> persist_query_families(normalized_theme_id, branch)
      end)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _changes} -> {:ok, list_branches(normalized_theme_id)}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  @spec list_branches(String.t()) :: [ResearchBranch.t()]
  def list_branches(normalized_theme_id) do
    query_families = from(family in QueryFamilyRecord, order_by: [asc: family.kind])
    joins = from(join in QueryFamilyQuery, preload: [:generated_query])

    Repo.all(
      from(branch in ResearchBranch,
        where: branch.normalized_theme_id == ^normalized_theme_id,
        order_by: [asc: branch.kind, asc: branch.label],
        preload: [
          query_families:
            ^from(family in query_families, preload: [query_family_queries: ^joins]),
          generated_queries: ^from(query in GeneratedQuery, order_by: [asc: query.text])
        ]
      )
    )
  end

  @spec get_branch(String.t()) :: ResearchBranch.t() | nil
  def get_branch(branch_id) do
    Repo.get(ResearchBranch, branch_id)
  end

  @spec branch_id(String.t(), Branch.t() | SearchQuery.t()) :: String.t()
  def branch_id(normalized_theme_id, %Branch{} = branch) do
    ArtifactId.build("branch", %{
      normalized_theme_id: normalized_theme_id,
      kind: branch.kind,
      label: branch.label
    })
  end

  def branch_id(normalized_theme_id, %SearchQuery{} = query) do
    ArtifactId.build("branch", %{
      normalized_theme_id: normalized_theme_id,
      kind: query.branch_kind,
      label: query.branch_label
    })
  end

  @spec generated_query_id(String.t(), SearchQuery.t()) :: String.t()
  def generated_query_id(normalized_theme_id, %SearchQuery{} = query) do
    ArtifactId.build("query", %{
      branch_id: branch_id(normalized_theme_id, query),
      text: query.text,
      scope_type: query.scope_type,
      source_family: query.source_family,
      scoped_pattern: query.scoped_pattern,
      source_hints: Enum.map(query.source_hints, & &1.label)
    })
  end

  @spec to_core_branch(ResearchBranch.t()) :: Branch.t()
  def to_core_branch(%ResearchBranch{} = branch) do
    %Branch{
      kind: String.to_existing_atom(branch.kind),
      label: branch.label,
      rationale: branch.rationale,
      theme_relation: branch.theme_relation,
      source_targeting_rationale: branch.source_targeting_rationale,
      preferred_source_families:
        Enum.map(branch.preferred_source_families, &String.to_existing_atom/1),
      query_families: []
    }
  end

  defp persist_query_families(multi, normalized_theme_id, %Branch{} = branch) do
    branch_id = branch_id(normalized_theme_id, branch)

    Enum.reduce(branch.query_families, multi, fn %QueryFamily{} = query_family, acc ->
      query_family_id = query_family_id(branch_id, query_family)

      acc
      |> Multi.insert(
        {:query_family, query_family_id},
        QueryFamilyRecord.changeset(%QueryFamilyRecord{}, %{
          id: query_family_id,
          research_branch_id: branch_id,
          kind: Atom.to_string(query_family.kind),
          rationale: query_family.rationale,
          source_families: Enum.map(query_family.source_families, &Atom.to_string/1)
        }),
        on_conflict: :nothing,
        conflict_target: :id
      )
      |> persist_queries(normalized_theme_id, query_family_id, branch_id, query_family.queries)
    end)
  end

  defp persist_queries(multi, normalized_theme_id, query_family_id, branch_id, queries) do
    Enum.reduce(queries, multi, fn %SearchQuery{} = query, acc ->
      generated_query_id = generated_query_id(normalized_theme_id, query)

      join_id =
        ArtifactId.build("query_family_query", %{
          query_family_id: query_family_id,
          query_id: generated_query_id
        })

      acc
      |> Multi.insert(
        {:generated_query, generated_query_id},
        GeneratedQuery.changeset(%GeneratedQuery{}, %{
          id: generated_query_id,
          research_branch_id: branch_id,
          text: query.text,
          scope_type: Atom.to_string(query.scope_type),
          source_family: query.source_family && Atom.to_string(query.source_family),
          scoped_pattern: query.scoped_pattern,
          branch_kind: query.branch_kind && Atom.to_string(query.branch_kind),
          branch_label: query.branch_label,
          source_hints: Enum.map(query.source_hints, & &1.label)
        }),
        on_conflict: :nothing,
        conflict_target: :id
      )
      |> Multi.insert(
        {:query_family_query, join_id},
        QueryFamilyQuery.changeset(%QueryFamilyQuery{}, %{
          id: join_id,
          query_family_id: query_family_id,
          generated_query_id: generated_query_id
        }),
        on_conflict: :nothing,
        conflict_target: [:query_family_id, :generated_query_id]
      )
    end)
  end

  defp query_family_id(branch_id, %QueryFamily{} = query_family) do
    ArtifactId.build("query_family", %{
      branch_id: branch_id,
      kind: query_family.kind,
      rationale: query_family.rationale,
      source_families: query_family.source_families
    })
  end
end
