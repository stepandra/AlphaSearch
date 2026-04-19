defmodule ResearchStore.Artifacts.ResearchBranch do
  use Ecto.Schema

  import Ecto.Changeset

  alias ResearchCore.Branch.BranchKind

  @branch_kinds Enum.map(BranchKind.all(), &Atom.to_string/1)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "research_branches" do
    field(:kind, :string)
    field(:label, :string)
    field(:rationale, :string)
    field(:theme_relation, :string)
    field(:source_targeting_rationale, :string)
    field(:preferred_source_families, {:array, :string}, default: [])

    belongs_to(:normalized_theme, ResearchStore.Artifacts.NormalizedTheme, type: :string)

    has_many(:query_families, ResearchStore.Artifacts.QueryFamily)
    has_many(:generated_queries, ResearchStore.Artifacts.GeneratedQuery)

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(branch, attrs) do
    branch
    |> cast(attrs, [
      :id,
      :normalized_theme_id,
      :kind,
      :label,
      :rationale,
      :theme_relation,
      :source_targeting_rationale,
      :preferred_source_families
    ])
    |> validate_required([:id, :normalized_theme_id, :kind, :label, :rationale, :theme_relation])
    |> validate_inclusion(:kind, @branch_kinds)
    |> foreign_key_constraint(:normalized_theme_id)
  end
end
