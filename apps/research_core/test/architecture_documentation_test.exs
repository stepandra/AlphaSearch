defmodule ResearchCore.ArchitectureDocumentationTest do
  use ExUnit.Case, async: true

  @doc_path Path.expand("../../../docs/architecture.md", __DIR__)

  test "architecture doc covers ownership, dependency direction, and future placement" do
    assert File.exists?(@doc_path)

    contents = File.read!(@doc_path)

    assert contents =~ "# Architecture Boundaries"
    assert contents =~ "## App Ownership"

    assert contents =~ "`research_core`"
    assert contents =~ "`research_jobs`"
    assert contents =~ "`research_store`"
    assert contents =~ "`research_web`"
    assert contents =~ "`research_observability`"

    assert contents =~ "## Current Dependency Direction"
    assert contents =~ "`research_core`: no umbrella dependencies"
    assert contents =~ "`research_store`: depends on `research_core` and `research_observability`"

    assert contents =~
             "`research_jobs`: depends on `research_core`, `research_store`, and `research_observability`"

    assert contents =~
             "`research_web`: depends on `research_core`, `research_jobs`, `research_store`, and `research_observability`"

    assert contents =~ "`research_observability`: no umbrella dependencies"

    assert contents =~ "## Future Placement"
    assert contents =~ "query generation"
    assert contents =~ "retrieval workers"
    assert contents =~ "corpus records / branches / runs"
    assert contents =~ "ops dashboards"
    assert contents =~ "metrics and instrumentation"

    assert contents =~ "## Forbidden Dependencies"

    assert contents =~
             "`research_core` must not depend on `research_store`, `research_jobs`, `research_web`, or `research_observability`"

    assert contents =~
             "`research_store` must not depend on `research_jobs` or `research_web`"

    assert contents =~ "`research_jobs` must not depend on `research_web`"

    assert contents =~
             "`research_observability` must not depend on `research_core`, `research_store`, `research_jobs`, or `research_web`"
  end
end
