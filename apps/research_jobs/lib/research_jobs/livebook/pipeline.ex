defmodule ResearchJobs.Livebook.Pipeline do
  @moduledoc """
  Notebook-facing helpers for the explicit theme-to-snapshot preparation path.
  """

  alias ResearchCore.Branch.{Branch, QueryFamily, SearchPlanGenerator}
  alias ResearchCore.Corpus.{QA, QAResult}
  alias ResearchCore.Retrieval.RetrievalRun
  alias ResearchCore.Theme.{Normalized, Normalizer}
  alias ResearchJobs.Corpus.RawRecordBuilder
  alias ResearchJobs.Retrieval.{BraveSearchAdapter, ExaSearchAdapter, JinaFetchAdapter, Policy}
  alias ResearchJobs.Retrieval.Pipeline, as: RetrievalPipeline
  alias ResearchJobs.Retrieval.{SerperSearchAdapter, TavilySearchAdapter}

  @search_adapters %{
    serper: SerperSearchAdapter,
    brave: BraveSearchAdapter,
    tavily: TavilySearchAdapter,
    exa: ExaSearchAdapter
  }

  @fetch_adapters %{
    jina: JinaFetchAdapter
  }

  @runtime_apps [:req]

  @spec ensure_runtime_apps_started() :: [map()]
  def ensure_runtime_apps_started do
    Enum.map(@runtime_apps, fn app ->
      case Application.ensure_all_started(app) do
        {:ok, started} ->
          %{app: app, status: :ok, started: started}

        {:error, {failed_app, reason}} ->
          raise """
          failed to start notebook runtime dependency #{inspect(app)} via #{inspect(failed_app)}:
          #{Exception.format_exit(reason)}
          """
      end
    end)
  end

  @spec normalize_theme(String.t()) :: {:ok, Normalized.t()} | {:error, atom()}
  def normalize_theme(raw_text) when is_binary(raw_text) do
    Normalizer.normalize(raw_text)
  end

  @spec normalize_theme!(String.t()) :: Normalized.t()
  def normalize_theme!(raw_text) when is_binary(raw_text) do
    case normalize_theme(raw_text) do
      {:ok, %Normalized{} = normalized_theme} -> normalized_theme
      {:error, reason} -> raise ArgumentError, "theme normalization failed: #{inspect(reason)}"
    end
  end

  @spec generate_branches(Normalized.t()) :: [Branch.t()]
  def generate_branches(%Normalized{} = normalized_theme) do
    SearchPlanGenerator.generate(normalized_theme)
  end

  @spec query_rows([Branch.t()]) :: [map()]
  def query_rows(branches) when is_list(branches) do
    for %Branch{} = branch <- branches,
        %QueryFamily{} = family <- branch.query_families,
        query <- family.queries do
      %{
        branch_kind: branch.kind,
        branch_label: branch.label,
        branch_rationale: branch.rationale,
        query_family_kind: family.kind,
        query_family_rationale: family.rationale,
        query: query,
        query_text: query.text,
        scope_type: query.scope_type,
        source_family: query.source_family,
        source_hints: Enum.map(query.source_hints, & &1.label)
      }
    end
  end

  @spec flatten_queries([Branch.t()]) :: list()
  def flatten_queries(branches) when is_list(branches) do
    branches
    |> query_rows()
    |> Enum.map(& &1.query)
  end

  @spec build_retrieval_pipeline(keyword()) ::
          {:ok, RetrievalPipeline.t()} | {:error, Exception.t()}
  def build_retrieval_pipeline(opts \\ []) do
    policy_opts = Keyword.get(opts, :policy_opts, [])

    with {:ok, policy} <- Policy.new(policy_opts),
         {:ok, pipeline} <-
           RetrievalPipeline.new(
             policy: policy,
             search_adapters:
               Keyword.get(
                 opts,
                 :search_adapters,
                 search_adapters_for(policy.search_provider_order)
               ),
             fetch_adapter:
               Keyword.get(opts, :fetch_adapter, fetch_adapter_for(policy.fetch_provider))
           ) do
      {:ok, pipeline}
    end
  end

  @spec build_retrieval_pipeline!(keyword()) :: RetrievalPipeline.t()
  def build_retrieval_pipeline!(opts \\ []) do
    case build_retrieval_pipeline(opts) do
      {:ok, %RetrievalPipeline{} = pipeline} -> pipeline
      {:error, error} -> raise error
    end
  end

  @spec run_retrieval(RetrievalPipeline.t(), list()) :: RetrievalRun.t()
  def run_retrieval(%RetrievalPipeline{} = pipeline, queries) when is_list(queries) do
    RetrievalPipeline.search(pipeline, queries)
  end

  @spec run_retrieval(list(), keyword()) :: RetrievalRun.t()
  def run_retrieval(queries, opts) when is_list(queries) and is_list(opts) do
    opts
    |> build_retrieval_pipeline!()
    |> run_retrieval(queries)
  end

  @spec build_raw_records(RetrievalRun.t(), Normalized.t() | nil, [Branch.t()]) :: list()
  def build_raw_records(%RetrievalRun{} = retrieval_run, theme, branches \\ [])
      when is_list(branches) do
    RawRecordBuilder.build(retrieval_run, theme, branches)
  end

  @spec run_qa(list()) :: QAResult.t()
  def run_qa(raw_records) when is_list(raw_records) do
    QA.process(raw_records)
  end

  @spec build_bundle(Normalized.t(), [Branch.t()], RetrievalRun.t(), QAResult.t(), keyword()) ::
          map()
  def build_bundle(
        %Normalized{} = normalized_theme,
        branches,
        %RetrievalRun{} = retrieval_run,
        %QAResult{} = qa_result,
        opts \\ []
      )
      when is_list(branches) do
    snapshot_id =
      Keyword.get(opts, :snapshot_id, synthetic_snapshot_id(normalized_theme, retrieval_run))

    normalized_theme_id =
      Keyword.get(opts, :normalized_theme_id, synthetic_theme_id(normalized_theme))

    finalized_at = Keyword.get(opts, :finalized_at, timestamp())

    %{
      snapshot: %{
        id: snapshot_id,
        label: Keyword.get(opts, :label, normalized_theme.normalized_text),
        finalized_at: finalized_at,
        normalized_theme_ids: [normalized_theme_id],
        branch_ids: Enum.map(branches, &synthetic_branch_id(normalized_theme_id, &1)),
        retrieval_run_ids: [retrieval_run.id],
        qa_summary: qa_result.qa_decision_summary
      },
      accepted_core: qa_result.accepted_core,
      accepted_analog: qa_result.accepted_analog,
      background: qa_result.background,
      quarantine: qa_result.quarantine,
      duplicate_groups: qa_result.duplicate_groups
    }
  end

  defp search_adapters_for(provider_names) do
    Map.take(@search_adapters, provider_names)
  end

  defp fetch_adapter_for(provider_name) do
    Map.fetch!(@fetch_adapters, provider_name)
  end

  defp synthetic_snapshot_id(normalized_theme, retrieval_run) do
    stable_id("snapshot", [normalized_theme.normalized_text, retrieval_run.id])
  end

  defp synthetic_theme_id(normalized_theme) do
    stable_id("theme", [normalized_theme.normalized_text])
  end

  defp synthetic_branch_id(normalized_theme_id, %Branch{} = branch) do
    stable_id("branch", [normalized_theme_id, branch.kind, branch.label])
  end

  defp stable_id(prefix, parts) do
    parts
    |> Enum.map(&to_string/1)
    |> Enum.join(":")
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 24)
    |> then(&"#{prefix}_#{&1}")
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end
end
