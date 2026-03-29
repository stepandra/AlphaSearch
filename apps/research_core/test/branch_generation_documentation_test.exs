defmodule ResearchCore.BranchGenerationDocumentationTest do
  use ExUnit.Case, async: true

  @doc_path Path.expand("../../../docs/branch_generation.md", __DIR__)

  test "branch generation doc covers source-scoped search behavior and limits" do
    assert File.exists?(@doc_path)

    contents = File.read!(@doc_path)

    assert contents =~ "# Branch Generation and Query Families"
    assert contents =~ "## Source Targeting and Scoped Search"
    assert contents =~ "`:source_scoped`"
    assert contents =~ "`preferred_source_families`"
    assert contents =~ "`academic_preprints`"
    assert contents =~ "`econ_working_papers`"
    assert contents =~ "`conference_proceedings`"
    assert contents =~ "`official_docs`"
    assert contents =~ "`official_sites`"
    assert contents =~ "`code_repositories`"
    assert contents =~ "`general_web`"
    assert contents =~ "site:arxiv.org"
    assert contents =~ "site:github.com"
    assert contents =~ "generic web search"
    assert contents =~ "## What This Patch Improves"
    assert contents =~ "## Still Not Solved"
    assert contents =~ "corpus QA"
    assert contents =~ "evidence scoring"
    assert contents =~ "synthesis"
  end
end
