defmodule ResearchStore.Artifacts.NormalizedTheme do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "normalized_themes" do
    field(:original_input, :string)
    field(:normalized_text, :string)
    field(:topic, :string)
    field(:objective_description, :string)
    field(:notes, :string)
    field(:domain_hints, {:array, :string}, default: [])
    field(:mechanism_hints, {:array, :string}, default: [])
    field(:constraints, {:array, :map}, default: [])

    belongs_to(:research_theme, ResearchStore.Artifacts.ResearchTheme, type: :string)

    has_many(:branches, ResearchStore.Artifacts.ResearchBranch)

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(theme, attrs) do
    theme
    |> cast(attrs, [
      :id,
      :research_theme_id,
      :original_input,
      :normalized_text,
      :topic,
      :objective_description,
      :notes,
      :domain_hints,
      :mechanism_hints,
      :constraints
    ])
    |> validate_required([:id, :research_theme_id, :original_input, :normalized_text, :topic])
    |> foreign_key_constraint(:research_theme_id)
  end
end
