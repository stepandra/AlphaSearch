defmodule ResearchJobs.Strategy.Models.FormulaExtractionBatch do
  @moduledoc false

  use Ecto.Schema
  use Instructor.Validator

  import Ecto.Changeset

  alias ResearchJobs.Strategy.Models.FormulaExtractionItem

  @primary_key false
  @type t :: %__MODULE__{}

  embedded_schema do
    embeds_many(:formulas, FormulaExtractionItem)
  end

  @impl true
  def validate_changeset(changeset) do
    cast_embed(changeset, :formulas, required: false)
  end

  @spec to_maps(t()) :: [map()]
  def to_maps(%__MODULE__{formulas: formulas}) do
    Enum.map(formulas, fn formula ->
      %{
        formula_text: formula.formula_text,
        exact?: formula.exact,
        partial?: formula.partial,
        blocked?: formula.blocked,
        role: formula.role,
        source_section_ids: formula.source_section_ids,
        supporting_citation_keys: formula.supporting_citation_keys,
        evidence_pairs: formula.evidence_pairs,
        symbol_glossary: formula.symbol_glossary,
        notes: formula.notes
      }
    end)
  end
end
