defmodule ResearchStore.ArtifactId do
  @moduledoc false

  @spec build(String.t(), term()) :: String.t()
  def build(prefix, value) when is_binary(prefix) do
    digest =
      value
      |> normalize()
      |> inspect(limit: :infinity, printable_limit: :infinity)
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 24)

    prefix <> "_" <> digest
  end

  @spec fingerprint(binary()) :: String.t()
  def fingerprint(value) when is_binary(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode16(case: :lower)
  end

  defp normalize(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp normalize(%Date{} = value), do: Date.to_iso8601(value)
  defp normalize(%Time{} = value), do: Time.to_iso8601(value)

  defp normalize(%_{} = value) do
    value
    |> Map.from_struct()
    |> normalize()
  end

  defp normalize(value) when is_map(value) do
    value
    |> Enum.map(fn {key, entry} -> {normalize(key), normalize(entry)} end)
    |> Enum.sort()
  end

  defp normalize(value) when is_list(value), do: Enum.map(value, &normalize/1)
  defp normalize(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize(value), do: value
end
