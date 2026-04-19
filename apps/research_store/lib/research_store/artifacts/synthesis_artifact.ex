defmodule ResearchStore.Artifacts.SynthesisArtifact do
  use Ecto.Schema

  import Ecto.Changeset

  @format_values ~w(markdown)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "synthesis_artifacts" do
    field(:profile_id, :string)
    field(:format, :string)
    field(:content, :string)
    field(:section_headings, {:array, :string}, default: [])
    field(:cited_keys, {:array, :string}, default: [])
    field(:artifact_hash, :string)
    field(:summary, :map, default: %{})
    field(:finalized_at, :utc_datetime_usec)

    belongs_to(:synthesis_run, ResearchStore.Artifacts.SynthesisRun, type: :string)
    belongs_to(:corpus_snapshot, ResearchStore.Artifacts.CorpusSnapshot, type: :string)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [
      :id,
      :synthesis_run_id,
      :corpus_snapshot_id,
      :profile_id,
      :format,
      :content,
      :section_headings,
      :cited_keys,
      :artifact_hash,
      :summary,
      :finalized_at
    ])
    |> validate_required([
      :id,
      :synthesis_run_id,
      :corpus_snapshot_id,
      :profile_id,
      :format,
      :content,
      :artifact_hash
    ])
    |> validate_inclusion(:format, @format_values)
    |> foreign_key_constraint(:synthesis_run_id)
    |> foreign_key_constraint(:corpus_snapshot_id)
    |> unique_constraint(:synthesis_run_id)
  end
end
