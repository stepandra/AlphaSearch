defmodule ResearchJobs.Strategy.Models.Caster do
  @moduledoc false

  @spec cast(module(), map() | struct()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def cast(model_module, %model_module{} = value), do: {:ok, value}

  def cast(model_module, attrs) when is_map(attrs) do
    changeset =
      model_module
      |> struct()
      |> Instructor.cast_all(attrs)
      |> model_module.validate_changeset()

    Ecto.Changeset.apply_action(changeset, :insert)
  end
end
