defmodule ResearchStore.Artifacts.SynthesisValidationResult do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "synthesis_validation_results" do
    field(:valid, :boolean, default: false)
    field(:structural_errors, {:array, :map}, default: [])
    field(:citation_errors, {:array, :map}, default: [])
    field(:formula_errors, {:array, :map}, default: [])
    field(:cited_keys, {:array, :string}, default: [])
    field(:allowed_keys, {:array, :string}, default: [])
    field(:unknown_keys, {:array, :string}, default: [])
    field(:metadata, :map, default: %{})
    field(:validated_at, :utc_datetime_usec)

    belongs_to(:synthesis_run, ResearchStore.Artifacts.SynthesisRun, type: :string)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(validation, attrs) do
    validation
    |> cast(attrs, [
      :id,
      :synthesis_run_id,
      :valid,
      :structural_errors,
      :citation_errors,
      :formula_errors,
      :cited_keys,
      :allowed_keys,
      :unknown_keys,
      :metadata,
      :validated_at
    ])
    |> validate_required([:id, :synthesis_run_id, :valid])
    |> foreign_key_constraint(:synthesis_run_id)
    |> unique_constraint(:synthesis_run_id)
  end
end
