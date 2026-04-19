defmodule ResearchStore.Artifacts.QueryFamily do
  use Ecto.Schema

  import Ecto.Changeset

  alias ResearchCore.Branch.QueryFamilyKind

  @family_kinds Enum.map(QueryFamilyKind.all(), &Atom.to_string/1)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "query_families" do
    field(:kind, :string)
    field(:rationale, :string)
    field(:source_families, {:array, :string}, default: [])

    belongs_to(:research_branch, ResearchStore.Artifacts.ResearchBranch, type: :string)

    has_many(:query_family_queries, ResearchStore.Artifacts.QueryFamilyQuery)

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(query_family, attrs) do
    query_family
    |> cast(attrs, [:id, :research_branch_id, :kind, :rationale, :source_families])
    |> validate_required([:id, :research_branch_id, :kind, :rationale])
    |> validate_inclusion(:kind, @family_kinds)
    |> foreign_key_constraint(:research_branch_id)
  end
end
