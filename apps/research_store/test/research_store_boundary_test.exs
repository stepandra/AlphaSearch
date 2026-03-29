defmodule ResearchStoreBoundaryTest do
  use ExUnit.Case, async: false

  @repo_root Path.expand("../../..", __DIR__)

  test "research_store owns the repo configuration" do
    assert Code.ensure_loaded?(ResearchStore.Repo)
    assert Application.get_env(:research_store, :ecto_repos) == [ResearchStore.Repo]
    assert Application.get_env(:research_store, ResearchStore.Repo)
    refute Code.ensure_loaded?(ResearchWeb.Repo)
    refute Application.get_env(:research_web, :ecto_repos)
  end

  test "umbrella app dependencies follow the intended boundary direction" do
    assert umbrella_deps("research_core") == []
    assert umbrella_deps("research_observability") == []
    assert umbrella_deps("research_store") == ["research_core", "research_observability"]

    assert umbrella_deps("research_jobs") == [
             "research_core",
             "research_observability",
             "research_store"
           ]

    assert umbrella_deps("research_web") == [
             "research_core",
             "research_jobs",
             "research_observability",
             "research_store"
           ]
  end

  defp umbrella_deps(app_name) do
    app_name
    |> mix_file_path()
    |> File.read!()
    |> then(&Regex.scan(~r/\{:?(research_[a-z_]+),\s*in_umbrella:\s*true\}/, &1))
    |> Enum.map(fn [_, dep_name] -> dep_name end)
    |> Enum.sort()
  end

  defp mix_file_path(app_name) do
    Path.join([@repo_root, "apps", app_name, "mix.exs"])
  end
end
