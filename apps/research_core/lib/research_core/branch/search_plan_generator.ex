defmodule ResearchCore.Branch.SearchPlanGenerator do
  @moduledoc """
  Pure function module that composes a complete search plan from a normalized theme.

  The search plan is represented as a list of fully populated `Branch.t()`
  structs. Each branch is generated in canonical branch-kind order, expanded
  into canonical query-family order, and deduplicated within each family so the
  returned output is explicit and ready for downstream retrieval wiring.
  """

  alias ResearchCore.Branch.{
    Branch,
    BranchGenerator,
    DuplicateSuppression,
    QueryFamily,
    QueryFamilyGenerator,
    SourceIntentMapping
  }

  alias ResearchCore.Theme.Normalized

  @doc """
  Generates fully populated branches for a normalized theme.

  Branch order follows `BranchGenerator.generate/1`, query-family order follows
  `QueryFamilyGenerator.generate/2`, and duplicate suppression is applied within
  each family before the branches are returned.
  """
  @spec generate(Normalized.t()) :: [Branch.t()]
  def generate(%Normalized{} = theme) do
    theme
    |> BranchGenerator.generate()
    |> Enum.map(&attach_query_families(&1, theme))
  end

  defp attach_query_families(%Branch{} = branch, %Normalized{} = theme) do
    recommendation = SourceIntentMapping.recommend(branch, theme)

    query_families =
      branch
      |> QueryFamilyGenerator.generate(theme)
      |> Enum.map(&deduplicate_queries/1)

    %Branch{
      branch
      | preferred_source_families: recommendation.preferred_source_families,
        source_targeting_rationale: recommendation.rationale,
        query_families: query_families
    }
  end

  defp deduplicate_queries(%QueryFamily{} = family) do
    %QueryFamily{family | queries: DuplicateSuppression.deduplicate(family.queries)}
  end
end
