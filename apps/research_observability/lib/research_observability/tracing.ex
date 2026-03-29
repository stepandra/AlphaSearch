defmodule ResearchObservability.Tracing do
  @moduledoc """
  Shared tracing bootstrap for Phoenix, Ecto, Bandit, and future Oban wiring.
  """

  @spec setup(keyword()) :: :ok
  def setup(opts \\ []) do
    opts
    |> Keyword.get(:phoenix)
    |> setup_phoenix()

    opts
    |> Keyword.get(:bandit)
    |> setup_bandit()

    opts
    |> Keyword.get(:ecto_event_prefixes, [])
    |> Enum.each(&OpentelemetryEcto.setup/1)

    opts
    |> Keyword.get(:oban)
    |> setup_oban()

    :ok
  end

  defp setup_phoenix(nil), do: :ok
  defp setup_phoenix(:disabled), do: :ok
  defp setup_phoenix(opts), do: OpentelemetryPhoenix.setup(opts)

  defp setup_bandit(nil), do: :ok
  defp setup_bandit(:disabled), do: :ok
  defp setup_bandit(opts), do: OpentelemetryBandit.setup(opts)

  defp setup_oban(nil), do: :ok
  defp setup_oban(:disabled), do: :ok
  defp setup_oban(opts), do: OpentelemetryOban.setup(opts)
end
