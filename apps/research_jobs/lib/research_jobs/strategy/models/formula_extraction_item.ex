defmodule ResearchJobs.Strategy.Models.FormulaExtractionItem do
  @moduledoc false

  use Ecto.Schema
  use Instructor.Validator

  import Ecto.Changeset

  @primary_key false
  @type t :: %__MODULE__{}

  embedded_schema do
    field(:formula_text, :string)
    field(:exact, :boolean, default: false)
    field(:partial, :boolean, default: false)
    field(:blocked, :boolean, default: false)

    field(:role, Ecto.Enum,
      values: [
        :calibration,
        :execution,
        :arbitrage_or_coherence,
        :sizing,
        :behavioral_adjustment,
        :other
      ]
    )

    field(:source_section_ids, {:array, :string}, default: [])
    field(:supporting_citation_keys, {:array, :string}, default: [])
    field(:evidence_pairs, {:array, :map}, default: [])
    field(:symbol_glossary, :map, default: %{})
    field(:notes, {:array, :string}, default: [])
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :formula_text,
      :exact,
      :partial,
      :blocked,
      :role,
      :source_section_ids,
      :supporting_citation_keys,
      :evidence_pairs,
      :symbol_glossary,
      :notes
    ])
    |> validate_changeset()
  end

  @impl true
  def validate_changeset(changeset) do
    changeset
    |> validate_required([:formula_text, :role])
    |> validate_length(:source_section_ids, min: 1)
    |> validate_length(:supporting_citation_keys, min: 1)
  end
end
