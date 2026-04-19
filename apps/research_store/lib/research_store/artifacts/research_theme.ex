defmodule ResearchStore.Artifacts.ResearchTheme do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @type t :: %__MODULE__{}

  schema "research_themes" do
    field(:raw_text, :string)
    field(:source, :string)
    field(:content_hash, :string)

    has_many(:normalized_themes, ResearchStore.Artifacts.NormalizedTheme)

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(theme, attrs) do
    theme
    |> cast(attrs, [:id, :raw_text, :source, :content_hash])
    |> validate_required([:id, :raw_text, :content_hash])
    |> unique_constraint(:content_hash)
  end
end
