defmodule ResearchJobs.Retrieval.ProviderConfigTest do
  use ExUnit.Case, async: true

  alias ResearchJobs.Retrieval.ProviderConfig

  @repo_root Path.expand("../../../../..", __DIR__)

  test "research_jobs declares req as a direct dependency for retrieval adapters" do
    mix_contents = mix_file_contents("research_jobs")

    assert mix_contents =~ "{:req,"
  end

  test "loads explicit provider placeholders for supported search and fetch providers" do
    assert [:serper, :brave, :tavily, :exa] = ProviderConfig.search_provider_order()
    assert :jina = ProviderConfig.fetch_provider()

    assert %{api_key_env: "SERPER_API_KEY", endpoint: "https://google.serper.dev/search"} =
             ProviderConfig.provider!(:serper)

    assert %{api_key_env: "JINA_API_KEY", endpoint: "https://r.jina.ai/http://"} =
             ProviderConfig.provider!(:jina)

    assert %{
             api_key_env: "BRAVE_API_KEY",
             endpoint: "https://api.search.brave.com/res/v1/web/search"
           } =
             ProviderConfig.provider!(:brave)

    assert %{api_key_env: "TAVILY_API_KEY", endpoint: "https://api.tavily.com/search"} =
             ProviderConfig.provider!(:tavily)

    assert %{api_key_env: "EXA_API_KEY", endpoint: "https://api.exa.ai/search"} =
             ProviderConfig.provider!(:exa)
  end

  test "exposes req defaults that build a request template without adapter logic" do
    req_options = ProviderConfig.req_options()

    assert [connect_options: [timeout: 5_000], receive_timeout: 15_000, retry: [max_retries: 0]] =
             req_options

    assert %Req.Request{} = ProviderConfig.new_request()
  end

  defp mix_file_contents(app_name) do
    Path.join([@repo_root, "apps", app_name, "mix.exs"])
    |> File.read!()
  end
end
