defmodule ResearchStore.RetrievalRegistry do
  @moduledoc """
  Persistence boundary for retrieval runs, search requests, normalized hits, and fetched documents.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias ResearchCore.Branch.SearchQuery

  alias ResearchCore.Retrieval.{
    FetchResult,
    FetchedDocument,
    NormalizedSearchHit,
    RetrievalRun,
    SearchRequest
  }

  alias ResearchStore.{ArtifactId, Branches, Json, Repo}
  alias ResearchStore.Artifacts.FetchedDocument, as: FetchedDocumentRecord
  alias ResearchStore.Artifacts.GeneratedQuery
  alias ResearchStore.Artifacts.NormalizedRetrievalHit, as: RetrievalHitRecord
  alias ResearchStore.Artifacts.NormalizedTheme
  alias ResearchStore.Artifacts.RetrievalRun, as: RetrievalRunRecord
  alias ResearchStore.Artifacts.SearchRequest, as: SearchRequestRecord

  @spec store_run(RetrievalRun.t(), keyword()) :: {:ok, RetrievalRunRecord.t()} | {:error, term()}
  def store_run(%RetrievalRun{} = run, opts) do
    normalized_theme_id = Keyword.fetch!(opts, :normalized_theme_id)

    Multi.new()
    |> Multi.run(:normalized_theme, fn repo, _changes ->
      case repo.get(NormalizedTheme, normalized_theme_id) do
        nil -> {:error, {:missing_normalized_theme, normalized_theme_id}}
        theme -> {:ok, theme}
      end
    end)
    |> Multi.insert(
      :run,
      RetrievalRunRecord.changeset(%RetrievalRunRecord{}, %{
        id: run.id,
        started_at: run.started_at,
        completed_at: run.completed_at,
        search_request_count: length(run.search_requests),
        provider_result_count: length(run.provider_results),
        fetch_request_count: length(run.fetch_requests),
        provider_error_count: length(run.provider_errors)
      }),
      on_conflict: :nothing,
      conflict_target: :id
    )
    |> Multi.run(:documents, fn repo, _changes -> persist_documents(repo, run.fetch_results) end)
    |> Multi.run(:search_requests, fn repo, _changes ->
      persist_search_requests(repo, run.id, normalized_theme_id, run.search_requests)
    end)
    |> Multi.run(:hits, fn repo, %{documents: documents, search_requests: search_requests} ->
      persist_hits(
        repo,
        run.id,
        normalized_theme_id,
        run.provider_results,
        search_requests,
        documents
      )
    end)
    |> Multi.run(:persisted_run, fn repo, _changes ->
      fetch_required(repo, RetrievalRunRecord, run.id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{persisted_run: persisted_run}} -> {:ok, persisted_run}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  @spec list_runs() :: [RetrievalRunRecord.t()]
  def list_runs do
    Repo.all(from(run in RetrievalRunRecord, order_by: [desc: run.inserted_at]))
  end

  defp persist_documents(repo, fetch_results) do
    fetch_results
    |> Enum.filter(&match?(%FetchResult{status: :ok, document: %FetchedDocument{}}, &1))
    |> Enum.reduce_while({:ok, %{}}, fn %FetchResult{document: document}, {:ok, acc} ->
      case insert_or_get_document(repo, document) do
        {:ok, stored} -> {:cont, {:ok, Map.put(acc, document.url, stored)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp persist_search_requests(repo, run_id, normalized_theme_id, search_requests) do
    Enum.reduce_while(search_requests, {:ok, %{}}, fn %SearchRequest{} = request, {:ok, acc} ->
      with {:ok, query_id} <- resolve_query_id(repo, normalized_theme_id, request.query),
           request_id <- search_request_id(run_id, query_id, request.provider),
           {:ok, _record} <-
             repo.insert(
               SearchRequestRecord.changeset(%SearchRequestRecord{}, %{
                 id: request_id,
                 retrieval_run_id: run_id,
                 generated_query_id: query_id,
                 provider: Atom.to_string(request.provider),
                 max_results: request.max_results
               }),
               on_conflict: :nothing,
               conflict_target: :id
             ) do
        {:cont, {:ok, Map.put(acc, {Atom.to_string(request.provider), query_id}, request_id)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp persist_hits(
         repo,
         run_id,
         normalized_theme_id,
         provider_results,
         search_requests,
         documents
       ) do
    Enum.reduce_while(provider_results, {:ok, []}, fn provider_result, {:ok, acc} ->
      provider = Atom.to_string(provider_result.provider)

      with {:ok, query_id} <-
             resolve_query_id(repo, normalized_theme_id, provider_result.request.query),
           {:ok, search_request_id} <-
             fetch_map(search_requests, {provider, query_id}, :missing_search_request) do
        result =
          Enum.reduce_while(provider_result.hits, {:ok, acc}, fn %NormalizedSearchHit{} = hit,
                                                                 {:ok, hit_acc} ->
            hit_id = hit_id(run_id, query_id, hit)
            fetched_document = Map.get(documents, hit.url)

            case repo.insert(
                   RetrievalHitRecord.changeset(%RetrievalHitRecord{}, %{
                     id: hit_id,
                     retrieval_run_id: run_id,
                     search_request_id: search_request_id,
                     generated_query_id: query_id,
                     fetched_document_id: fetched_document && fetched_document.id,
                     provider: Atom.to_string(hit.provider),
                     rank: hit.rank,
                     title: hit.title,
                     url: hit.url,
                     snippet: hit.snippet,
                     raw_payload: Json.normalize(hit.raw_payload),
                     fetch_status: Atom.to_string(hit.fetch_status)
                   }),
                   on_conflict: :nothing,
                   conflict_target: :id
                 ) do
              {:ok, _record} -> {:cont, {:ok, [hit_id | hit_acc]}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
          end)

        case result do
          {:ok, ids} -> {:cont, {:ok, ids}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp insert_or_get_document(repo, %FetchedDocument{} = document) do
    document_id = document_id(document)
    content_fingerprint = ArtifactId.fingerprint(document.content)

    case fetch_document(repo, document_id, document.url, content_fingerprint) do
      {:ok, stored} ->
        {:ok, stored}

      {:error, :missing_fetched_document} ->
        do_insert_document(repo, document, document_id, content_fingerprint)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_insert_document(repo, %FetchedDocument{} = document, document_id, content_fingerprint) do
    changeset =
      %{
        id: document_id,
        url: document.url,
        content: document.content,
        content_format: Atom.to_string(document.content_format),
        title: document.title,
        fetched_at: document.fetched_at,
        content_fingerprint: content_fingerprint
      }
      |> maybe_put(:raw_payload, Json.normalize(document.raw_payload))
      |> then(&FetchedDocumentRecord.changeset(%FetchedDocumentRecord{}, &1))

    case repo.insert(changeset, on_conflict: :nothing, conflict_target: :id) do
      {:ok, _record} ->
        fetch_document(repo, document_id, document.url, content_fingerprint)

      {:error, changeset} ->
        if duplicate_fetched_document_error?(changeset) do
          fetch_document(repo, document_id, document.url, content_fingerprint)
        else
          {:error, changeset}
        end
    end
  end

  defp resolve_query_id(repo, normalized_theme_id, %SearchQuery{} = query) do
    query_id = Branches.generated_query_id(normalized_theme_id, query)

    case repo.get(GeneratedQuery, query_id) do
      nil -> {:error, {:missing_generated_query, query_id, query.text}}
      _record -> {:ok, query_id}
    end
  end

  defp search_request_id(run_id, query_id, provider) do
    ArtifactId.build("search_request", %{
      run_id: run_id,
      provider: provider,
      query_id: query_id
    })
  end

  defp hit_id(run_id, query_id, %NormalizedSearchHit{} = hit) do
    ArtifactId.build("retrieval_hit", %{
      run_id: run_id,
      query_id: query_id,
      provider: hit.provider,
      rank: hit.rank,
      url: hit.url
    })
  end

  defp document_id(%FetchedDocument{} = document) do
    ArtifactId.build("fetched_document", %{
      url: document.url,
      content_fingerprint: ArtifactId.fingerprint(document.content)
    })
  end

  defp fetch_document(repo, document_id, url, content_fingerprint) do
    case repo.one(
           from(fetched_document in FetchedDocumentRecord,
             where:
               fetched_document.id == ^document_id or
                 fetched_document.url == ^url or
                 fetched_document.content_fingerprint == ^content_fingerprint
           )
         ) do
      nil -> {:error, :missing_fetched_document}
      record -> {:ok, record}
    end
  end

  defp duplicate_fetched_document_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {field, {_message, details}} ->
      field in [:url, :content_fingerprint] and Keyword.get(details, :constraint) == :unique
    end)
  end

  defp maybe_put(attrs, _key, nil), do: attrs
  defp maybe_put(attrs, key, value), do: Map.put(attrs, key, value)

  defp fetch_required(repo, schema, id) do
    case repo.get(schema, id) do
      nil -> {:error, {:missing_record, schema, id}}
      record -> {:ok, record}
    end
  end

  defp fetch_map(map, key, label) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {label, key}}
    end
  end
end
