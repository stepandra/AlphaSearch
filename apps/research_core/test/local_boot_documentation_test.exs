defmodule ResearchCore.LocalBootDocumentationTest do
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../../README.md", __DIR__)

  test "root readme documents local boot workflow and umbrella layout" do
    assert File.exists?(@readme_path)

    contents = File.read!(@readme_path)

    assert contents =~ "## Local Boot Workflow"
    assert contents =~ "cd apps/research_web"
    assert contents =~ "mix phx.server"
    assert contents =~ "/health"
    assert contents =~ "localhost:5432"
    assert contents =~ "`mix precommit`"
    assert contents =~ "## Project Layout"

    assert contents =~ "`apps/research_core`"
    assert contents =~ "`apps/research_jobs`"
    assert contents =~ "`apps/research_store`"
    assert contents =~ "`apps/research_web`"
    assert contents =~ "`apps/research_observability`"
  end
end
