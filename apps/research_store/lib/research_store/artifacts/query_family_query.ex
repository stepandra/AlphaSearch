defmodule ResearchStore.Artifacts.QueryFamilyQuery do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "query_family_queries" do
    belongs_to(:query_family, ResearchStore.Artifacts.QueryFamily, type: :string)

    belongs_to(:generated_query, ResearchStore.Artifacts.GeneratedQuery, type: :string)

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(join, attrs) do
    join
    |> cast(attrs, [:id, :query_family_id, :generated_query_id])
    |> validate_required([:id, :query_family_id, :generated_query_id])
    |> foreign_key_constraint(:query_family_id)
    |> foreign_key_constraint(:generated_query_id)
    |> unique_constraint([:query_family_id, :generated_query_id])
  end
end
