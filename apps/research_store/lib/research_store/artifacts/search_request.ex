defmodule ResearchStore.Artifacts.SearchRequest do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "retrieval_search_requests" do
    field(:provider, :string)
    field(:max_results, :integer)

    belongs_to(:retrieval_run, ResearchStore.Artifacts.RetrievalRun, type: :string)

    belongs_to(:generated_query, ResearchStore.Artifacts.GeneratedQuery, type: :string)

    has_many(:retrieval_hits, ResearchStore.Artifacts.NormalizedRetrievalHit)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(request, attrs) do
    request
    |> cast(attrs, [:id, :retrieval_run_id, :generated_query_id, :provider, :max_results])
    |> validate_required([:id, :retrieval_run_id, :generated_query_id, :provider])
    |> validate_number(:max_results, greater_than: 0)
    |> foreign_key_constraint(:retrieval_run_id)
    |> foreign_key_constraint(:generated_query_id)
  end
end
