defmodule ResearchCore.Corpus.SourceIdentifiers do
  @moduledoc """
  Canonical source identifiers retained on a corpus record.
  """

  defstruct doi: nil, arxiv: nil, ssrn: nil, nber: nil, osf: nil, url: nil

  @type t :: %__MODULE__{
          doi: String.t() | nil,
          arxiv: String.t() | nil,
          ssrn: String.t() | nil,
          nber: String.t() | nil,
          osf: String.t() | nil,
          url: String.t() | nil
        }

  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{} = identifiers) do
    identifiers
    |> Map.from_struct()
    |> Enum.count(fn {_key, value} -> present?(value) end)
  end

  @spec blank?(t()) :: boolean()
  def blank?(%__MODULE__{} = identifiers), do: count(identifiers) == 0

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
