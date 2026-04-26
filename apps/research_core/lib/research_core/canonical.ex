defmodule ResearchCore.Canonical do
  @moduledoc """
  Canonical serialization helpers for replayable artifact and provider boundaries.
  """

  @schema_version "research_core.canonical.v1"

  @spec encode!(term()) :: binary()
  def encode!(value) do
    value
    |> envelope()
    |> Jason.encode!(maps: :strict)
  end

  @spec hash(term()) :: binary()
  def hash(value) do
    :crypto.hash(:sha256, encode!(value))
    |> Base.encode16(case: :lower)
  end

  defp envelope(value) do
    Jason.OrderedObject.new([
      {"schema_version", @schema_version},
      {"value", normalize(value)}
    ])
  end

  defp normalize(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize(%Date{} = value), do: Date.to_iso8601(value)
  defp normalize(%Time{} = value), do: Time.to_iso8601(value)

  defp normalize(%_{} = value) do
    value
    |> Map.from_struct()
    |> normalize()
  end

  defp normalize(nil), do: nil
  defp normalize(value) when is_boolean(value), do: value

  defp normalize(value) when is_map(value) do
    value
    |> Enum.map(fn {key, entry} -> {normalize_key(key), normalize(entry)} end)
    |> Enum.sort_by(fn {key, _entry} -> key end)
    |> Jason.OrderedObject.new()
  end

  defp normalize(value) when is_list(value), do: Enum.map(value, &normalize/1)
  defp normalize(value) when is_tuple(value), do: value |> Tuple.to_list() |> normalize()
  defp normalize(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize(value), do: value

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key), do: key |> normalize() |> Jason.encode!()
end
