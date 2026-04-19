defmodule ResearchStore.Artifacts.RetrievalRun do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "retrieval_runs" do
    field(:started_at, :utc_datetime_usec)
    field(:completed_at, :utc_datetime_usec)
    field(:search_request_count, :integer, default: 0)
    field(:provider_result_count, :integer, default: 0)
    field(:fetch_request_count, :integer, default: 0)
    field(:provider_error_count, :integer, default: 0)

    has_many(:search_requests, ResearchStore.Artifacts.SearchRequest)
    has_many(:retrieval_hits, ResearchStore.Artifacts.NormalizedRetrievalHit)
    has_many(:raw_corpus_records, ResearchStore.Artifacts.RawCorpusRecord)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :id,
      :started_at,
      :completed_at,
      :search_request_count,
      :provider_result_count,
      :fetch_request_count,
      :provider_error_count
    ])
    |> validate_required([:id])
    |> validate_number(:search_request_count, greater_than_or_equal_to: 0)
    |> validate_number(:provider_result_count, greater_than_or_equal_to: 0)
    |> validate_number(:fetch_request_count, greater_than_or_equal_to: 0)
    |> validate_number(:provider_error_count, greater_than_or_equal_to: 0)
  end
end
