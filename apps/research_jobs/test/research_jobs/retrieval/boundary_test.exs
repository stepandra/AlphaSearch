defmodule ResearchJobs.Retrieval.BoundarySearchAdapterStub do
  @behaviour ResearchJobs.Retrieval.SearchAdapter

  def search(_request, _opts), do: {:ok, :search_not_executed}
end

defmodule ResearchJobs.Retrieval.BoundaryFetchAdapterStub do
  @behaviour ResearchJobs.Retrieval.FetchAdapter

  def fetch(_request, _opts), do: {:ok, :fetch_not_executed}
end

defmodule ResearchJobs.Retrieval.InvalidSearchAdapterStub do
  def search(_request), do: {:ok, :wrong_arity}
end

defmodule ResearchJobs.Retrieval.InvalidFetchAdapterStub do
  def fetch(_request), do: {:ok, :wrong_arity}
end

defmodule ResearchJobs.Retrieval.BoundaryTest do
  use ExUnit.Case, async: false

  alias ResearchJobs.Retrieval.{Pipeline, Policy, ProviderConfig}

  @repo_root Path.expand("../../../../..", __DIR__)

  test "research_jobs declares nimble_options as a direct dependency for retrieval policy validation" do
    mix_contents = mix_file_contents("research_jobs")

    assert mix_contents =~ "{:nimble_options,"
  end

  describe "Policy" do
    test "builds validated defaults from the provider scaffold" do
      assert %Policy{
               search_provider_order: [:serper, :brave, :tavily, :exa],
               fetch_provider: :jina,
               req_options: req_options,
               max_results_per_query: 10,
               fallback_enabled: true,
               fetch_enabled: true,
               fetch_limit_per_query: 3
             } = Policy.default()

      assert req_options == ProviderConfig.req_options()
    end

    test "reads provider-backed defaults at runtime" do
      original_config = Application.fetch_env!(:research_jobs, ProviderConfig)

      runtime_config =
        Keyword.merge(original_config,
          search_provider_order: [:exa],
          req_options: [receive_timeout: 1_234]
        )

      on_exit(fn ->
        Application.put_env(:research_jobs, ProviderConfig, original_config)
      end)

      Application.put_env(:research_jobs, ProviderConfig, runtime_config)

      assert %Policy{
               search_provider_order: [:exa],
               fetch_provider: :jina,
               req_options: [receive_timeout: 1_234]
             } = Policy.default()

      assert %Pipeline{
               policy: %Policy{
                 search_provider_order: [:exa],
                 fetch_provider: :jina,
                 req_options: [receive_timeout: 1_234]
               }
             } = Pipeline.new!()
    end

    test "rejects unsupported providers and invalid limits" do
      assert {:error, %NimbleOptions.ValidationError{} = search_error} =
               Policy.new(search_provider_order: [:serper, :jina])

      assert Exception.message(search_error) =~ ":search_provider_order"

      assert {:error, %NimbleOptions.ValidationError{} = limit_error} =
               Policy.new(fetch_limit_per_query: 0)

      assert Exception.message(limit_error) =~ ":fetch_limit_per_query"
    end

    test "rejects duplicate providers in priority order" do
      assert {:error, %NimbleOptions.ValidationError{} = duplicate_error} =
               Policy.new(search_provider_order: [:serper, :serper])

      assert Exception.message(duplicate_error) =~ ":search_provider_order"
      assert Exception.message(duplicate_error) =~ "duplicate"
    end
  end

  describe "Pipeline" do
    test "scaffolds orchestration with a validated policy and empty adapters by default" do
      policy = Policy.default()

      assert %Pipeline{
               policy: ^policy,
               search_adapters: %{},
               fetch_adapter: nil
             } = Pipeline.new!()
    end

    test "accepts adapter modules that expose the expected callback arities" do
      assert %Pipeline{
               policy: %Policy{},
               search_adapters: %{serper: ResearchJobs.Retrieval.BoundarySearchAdapterStub},
               fetch_adapter: ResearchJobs.Retrieval.BoundaryFetchAdapterStub
             } =
               Pipeline.new!(
                 search_adapters: %{
                   serper: ResearchJobs.Retrieval.BoundarySearchAdapterStub
                 },
                 fetch_adapter: ResearchJobs.Retrieval.BoundaryFetchAdapterStub
               )
    end

    test "rejects adapter modules that do not expose the expected callbacks" do
      assert {:error, %ArgumentError{} = search_error} =
               Pipeline.new(
                 search_adapters: %{
                   serper: ResearchJobs.Retrieval.InvalidSearchAdapterStub
                 }
               )

      assert Exception.message(search_error) =~ "search/2"

      assert {:error, %ArgumentError{} = fetch_error} =
               Pipeline.new(fetch_adapter: ResearchJobs.Retrieval.InvalidFetchAdapterStub)

      assert Exception.message(fetch_error) =~ "fetch/2"
    end
  end

  defp mix_file_contents(app_name) do
    Path.join([@repo_root, "apps", app_name, "mix.exs"])
    |> File.read!()
  end
end
