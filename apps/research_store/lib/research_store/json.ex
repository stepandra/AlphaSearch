defmodule ResearchStore.Json do
  @moduledoc false

  @spec normalize(term()) :: term()
  def normalize(nil), do: nil
  def normalize(%DateTime{} = value), do: DateTime.to_iso8601(value)
  def normalize(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  def normalize(%Date{} = value), do: Date.to_iso8601(value)
  def normalize(%Time{} = value), do: Time.to_iso8601(value)

  def normalize(%_{} = value) do
    value
    |> Map.from_struct()
    |> normalize()
  end

  def normalize(value) when is_map(value) do
    Map.new(value, fn {key, entry} -> {to_string(key), normalize(entry)} end)
  end

  def normalize(value) when is_list(value), do: Enum.map(value, &normalize/1)
  def normalize(value) when is_atom(value), do: Atom.to_string(value)
  def normalize(value), do: value
end
