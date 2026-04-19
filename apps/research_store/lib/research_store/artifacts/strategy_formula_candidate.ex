defmodule ResearchStore.Artifacts.StrategyFormulaCandidate do
  use Ecto.Schema

  import Ecto.Changeset

  alias ResearchCore.Strategy.FormulaRole

  @role_values Enum.map(FormulaRole.values(), &Atom.to_string/1)
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "strategy_formula_candidates" do
    field(:formula_text, :string)
    field(:exact, :boolean, default: false)
    field(:partial, :boolean, default: false)
    field(:blocked, :boolean, default: false)
    field(:role, :string)
    field(:symbol_glossary, :map, default: %{})
    field(:source_section_ids, {:array, :string}, default: [])
    field(:source_section_headings, {:array, :string}, default: [])
    field(:supporting_citation_keys, {:array, :string}, default: [])
    field(:supporting_record_ids, {:array, :string}, default: [])
    field(:evidence_links, {:array, :map}, default: [])
    field(:notes, {:array, :string}, default: [])

    belongs_to(:strategy_extraction_run, ResearchStore.Artifacts.StrategyExtractionRun,
      type: :string
    )

    belongs_to(:corpus_snapshot, ResearchStore.Artifacts.CorpusSnapshot, type: :string)
    belongs_to(:synthesis_artifact, ResearchStore.Artifacts.SynthesisArtifact, type: :string)

    timestamps(updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(formula, attrs) do
    formula
    |> cast(attrs, [
      :id,
      :strategy_extraction_run_id,
      :corpus_snapshot_id,
      :synthesis_artifact_id,
      :formula_text,
      :exact,
      :partial,
      :blocked,
      :role,
      :symbol_glossary,
      :source_section_ids,
      :source_section_headings,
      :supporting_citation_keys,
      :supporting_record_ids,
      :evidence_links,
      :notes
    ])
    |> validate_required([
      :id,
      :strategy_extraction_run_id,
      :corpus_snapshot_id,
      :synthesis_artifact_id,
      :formula_text,
      :role
    ])
    |> validate_inclusion(:role, @role_values)
    |> foreign_key_constraint(:strategy_extraction_run_id)
    |> foreign_key_constraint(:corpus_snapshot_id)
    |> foreign_key_constraint(:synthesis_artifact_id)
  end
end
