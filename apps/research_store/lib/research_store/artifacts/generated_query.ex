defmodule ResearchStore.Artifacts.GeneratedQuery do
  use Ecto.Schema

  import Ecto.Changeset

  @scope_types ["generic", "source_scoped"]
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "generated_queries" do
    field(:text, :string)
    field(:scope_type, :string, default: "generic")
    field(:source_family, :string)
    field(:scoped_pattern, :string)
    field(:branch_kind, :string)
    field(:branch_label, :string)
    field(:source_hints, {:array, :string}, default: [])

    belongs_to(:research_branch, ResearchStore.Artifacts.ResearchBranch, type: :string)

    has_many(:query_family_queries, ResearchStore.Artifacts.QueryFamilyQuery)
    has_many(:search_requests, ResearchStore.Artifacts.SearchRequest)
    has_many(:retrieval_hits, ResearchStore.Artifacts.NormalizedRetrievalHit)

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(query, attrs) do
    query
    |> cast(attrs, [
      :id,
      :research_branch_id,
      :text,
      :scope_type,
      :source_family,
      :scoped_pattern,
      :branch_kind,
      :branch_label,
      :source_hints
    ])
    |> validate_required([:id, :research_branch_id, :text, :scope_type])
    |> validate_inclusion(:scope_type, @scope_types)
    |> foreign_key_constraint(:research_branch_id)
  end
end
