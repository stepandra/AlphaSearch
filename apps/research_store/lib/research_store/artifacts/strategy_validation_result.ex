defmodule ResearchStore.Artifacts.StrategyValidationResult do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "strategy_validation_results" do
    field(:valid, :boolean, default: false)
    field(:fatal_errors, {:array, :map}, default: [])
    field(:warnings, {:array, :map}, default: [])
    field(:rejected_formulas, {:array, :map}, default: [])
    field(:rejected_candidates, {:array, :map}, default: [])
    field(:duplicate_groups, {:array, :map}, default: [])
    field(:accepted_formula_ids, {:array, :string}, default: [])
    field(:accepted_strategy_ids, {:array, :string}, default: [])
    field(:validated_at, :utc_datetime_usec)

    belongs_to(:strategy_extraction_run, ResearchStore.Artifacts.StrategyExtractionRun,
      type: :string
    )

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(validation, attrs) do
    validation
    |> cast(attrs, [
      :id,
      :strategy_extraction_run_id,
      :valid,
      :fatal_errors,
      :warnings,
      :rejected_formulas,
      :rejected_candidates,
      :duplicate_groups,
      :accepted_formula_ids,
      :accepted_strategy_ids,
      :validated_at
    ])
    |> validate_required([:id, :strategy_extraction_run_id, :valid])
    |> foreign_key_constraint(:strategy_extraction_run_id)
    |> unique_constraint(:strategy_extraction_run_id)
  end
end
