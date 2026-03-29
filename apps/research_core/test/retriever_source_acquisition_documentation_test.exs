defmodule ResearchCore.RetrieverSourceAcquisitionDocumentationTest do
  use ExUnit.Case, async: true

  @doc_path Path.expand("../../../docs/retriever_source_acquisition.md", __DIR__)

  test "retrieval doc covers provider roles guarantees and example flows" do
    assert File.exists?(@doc_path)

    contents = File.read!(@doc_path)

    assert contents =~ "# Retriever Source Acquisition"
    assert contents =~ "## Supported Providers"
    assert contents =~ "`SERPER`"
    assert contents =~ "`JINA`"
    assert contents =~ "`BRAVE`"
    assert contents =~ "`TAVILY`"
    assert contents =~ "`EXA`"

    assert contents =~ "## Provider Policy"
    assert contents =~ "`[:serper, :brave, :tavily, :exa]`"
    assert contents =~ "`:jina`"
    assert contents =~ "`fetch_enabled`"
    assert contents =~ "`fetch_limit_per_query`"

    assert contents =~ "## Scoped-First Search Behavior"
    assert contents =~ "source_scoped"
    assert contents =~ "generic"
    assert contents =~ "branch_label"

    assert contents =~ "## Basic Search Only Boundaries"
    assert contents =~ "Tavily"
    assert contents =~ "Exa"
    assert contents =~ "answer"
    assert contents =~ "extract"
    assert contents =~ "crawl"
    assert contents =~ "deep research"

    assert contents =~ "## Guarantees"
    assert contents =~ "provider_errors"
    assert contents =~ "fetch_results"
    assert contents =~ "Exact duplicate URLs are fetched at most once"
    assert contents =~ "scoped queries run before generic"

    assert contents =~ "## Non-Goals"
    assert contents =~ "corpus QA"
    assert contents =~ "evidence scoring"
    assert contents =~ "synthesis"

    assert contents =~ "## Example Retrieval Flows"
    assert contents =~ "RetrievalRun"
    assert contents =~ "ProviderResult"
    assert contents =~ "NormalizedSearchHit"
    assert contents =~ "FetchRequest"
    assert contents =~ "FetchResult"
  end
end
