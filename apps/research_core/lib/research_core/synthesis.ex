defmodule ResearchCore.Synthesis do
  @moduledoc """
  Explicit synthesis profile registry.

  Synthesis turns a finalized corpus snapshot into a reproducible report artifact.
  The registry stays versioned and concrete rather than becoming a generic prompt
  engine.
  """

  alias ResearchCore.Synthesis.Profile
  alias ResearchCore.Synthesis.Profiles.LiteratureReviewV1

  @profiles %{
    "literature_review_v1" => LiteratureReviewV1
  }

  @type profile_id :: String.t()

  @spec profile(profile_id()) :: {:ok, Profile.t()} | {:error, {:unknown_profile, profile_id()}}
  def profile(profile_id) when is_binary(profile_id) do
    case Map.fetch(@profiles, profile_id) do
      {:ok, module} -> {:ok, module.definition()}
      :error -> {:error, {:unknown_profile, profile_id}}
    end
  end

  @spec profile!(profile_id()) :: Profile.t()
  def profile!(profile_id) do
    case profile(profile_id) do
      {:ok, profile} -> profile
      {:error, reason} -> raise ArgumentError, "unknown synthesis profile: #{inspect(reason)}"
    end
  end

  @spec profile_ids() :: [profile_id()]
  def profile_ids do
    @profiles
    |> Map.keys()
    |> Enum.sort()
  end
end
