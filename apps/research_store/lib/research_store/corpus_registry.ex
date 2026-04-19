defmodule ResearchStore.CorpusRegistry do
  @moduledoc """
  Persistence boundary for raw corpus records, QA outputs, and immutable corpus snapshots.
  """

  import Ecto.Query

  alias ResearchCore.Branch.{Branch, SearchQuery}

  alias ResearchCore.Corpus.{
    AcceptanceDecision,
    CanonicalRecord,
    DuplicateGroup,
    QAResult,
    QuarantineRecord,
    RawRecord,
    SourceIdentifiers,
    SourceProvenanceSummary
  }

  alias ResearchCore.Retrieval.{FetchedDocument, NormalizedSearchHit}
  alias ResearchStore.{ArtifactId, Branches, Json, Repo, Themes}
  alias ResearchStore.Artifacts.CanonicalCorpusRecord, as: CanonicalRecordSchema
  alias ResearchStore.Artifacts.CorpusSnapshot
  alias ResearchStore.Artifacts.CorpusSnapshotQuarantine, as: SnapshotQuarantine
  alias ResearchStore.Artifacts.CorpusSnapshotRecord, as: SnapshotRecord
  alias ResearchStore.Artifacts.DuplicateGroup, as: DuplicateGroupSchema
  alias ResearchStore.Artifacts.FetchedDocument, as: FetchedDocumentSchema
  alias ResearchStore.Artifacts.GeneratedQuery
  alias ResearchStore.Artifacts.NormalizedRetrievalHit, as: RetrievalHitSchema
  alias ResearchStore.Artifacts.QADecision, as: QADecisionSchema
  alias ResearchStore.Artifacts.QuarantineRecord, as: QuarantineRecordSchema
  alias ResearchStore.Artifacts.RawCorpusRecord, as: RawRecordSchema
  alias ResearchStore.Artifacts.RetrievalRun, as: RetrievalRunSchema

  @spec store_qa_artifacts([RawRecord.t()], QAResult.t(), keyword()) ::
          {:ok,
           %{
             raw_records: [RawRecordSchema.t()],
             canonical_records: [CanonicalRecordSchema.t()],
             duplicate_groups: [DuplicateGroupSchema.t()],
             decisions: [QADecisionSchema.t()],
             quarantine_records: [QuarantineRecordSchema.t()]
           }}
          | {:error, term()}
  def store_qa_artifacts(raw_records, %QAResult{} = qa_result, opts \\ []) do
    Repo.transaction(fn ->
      case persist_qa_graph(Repo, raw_records, qa_result, opts) do
        {:ok, persisted} -> persisted
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> unwrap_transaction()
  end

  @spec create_snapshot([RawRecord.t()], QAResult.t(), keyword()) ::
          {:ok, CorpusSnapshot.t()} | {:error, term()}
  def create_snapshot(raw_records, %QAResult{} = qa_result, opts \\ []) do
    Repo.transaction(fn ->
      with {:ok, persisted} <- persist_qa_graph(Repo, raw_records, qa_result, opts),
           {:ok, snapshot} <- persist_snapshot(Repo, persisted, qa_result, opts) do
        snapshot
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> unwrap_transaction()
  end

  @spec get_snapshot(String.t()) :: CorpusSnapshot.t() | nil
  def get_snapshot(snapshot_id), do: Repo.get(CorpusSnapshot, snapshot_id)

  @spec list_snapshots() :: [CorpusSnapshot.t()]
  def list_snapshots do
    Repo.all(
      from(snapshot in CorpusSnapshot,
        order_by: [desc: snapshot.finalized_at, desc: snapshot.inserted_at]
      )
    )
  end

  @spec latest_snapshot_for_branch(String.t()) :: CorpusSnapshot.t() | nil
  def latest_snapshot_for_branch(branch_id) do
    Repo.one(
      from(snapshot in CorpusSnapshot,
        where: fragment("? @> ARRAY[?]::varchar[]", snapshot.branch_ids, ^branch_id),
        order_by: [desc: snapshot.finalized_at, desc: snapshot.inserted_at],
        limit: 1
      )
    )
  end

  @spec latest_snapshot_for_theme(String.t()) :: CorpusSnapshot.t() | nil
  def latest_snapshot_for_theme(normalized_theme_id) do
    Repo.one(
      from(snapshot in CorpusSnapshot,
        where:
          fragment(
            "? @> ARRAY[?]::varchar[]",
            snapshot.normalized_theme_ids,
            ^normalized_theme_id
          ),
        order_by: [desc: snapshot.finalized_at, desc: snapshot.inserted_at],
        limit: 1
      )
    )
  end

  @spec load_snapshot(String.t()) ::
          {:ok,
           %{
             snapshot: CorpusSnapshot.t(),
             accepted_core: [CanonicalRecord.t()],
             accepted_analog: [CanonicalRecord.t()],
             background: [CanonicalRecord.t()],
             quarantine: [QuarantineRecord.t()],
             duplicate_groups: [DuplicateGroup.t()]
           }}
          | {:error, term()}
  def load_snapshot(snapshot_id) do
    with %CorpusSnapshot{} = snapshot <- Repo.get(CorpusSnapshot, snapshot_id) do
      {:ok,
       %{
         snapshot: snapshot,
         accepted_core: accepted_core_records(snapshot.id),
         accepted_analog: accepted_analog_records(snapshot.id),
         background: background_records(snapshot.id),
         quarantine: quarantine_records(snapshot.id),
         duplicate_groups: duplicate_groups(snapshot.id)
       }}
    else
      nil -> {:error, {:missing_snapshot, snapshot_id}}
    end
  end

  @spec accepted_core_records(String.t()) :: [CanonicalRecord.t()]
  def accepted_core_records(snapshot_id), do: snapshot_records(snapshot_id, :accepted_core)

  @spec accepted_analog_records(String.t()) :: [CanonicalRecord.t()]
  def accepted_analog_records(snapshot_id), do: snapshot_records(snapshot_id, :accepted_analog)

  @spec background_records(String.t()) :: [CanonicalRecord.t()]
  def background_records(snapshot_id), do: snapshot_records(snapshot_id, :background)

  @spec quarantine_records(String.t()) :: [QuarantineRecord.t()]
  def quarantine_records(snapshot_id) do
    Repo.all(
      from(snapshot_quarantine in SnapshotQuarantine,
        where: snapshot_quarantine.corpus_snapshot_id == ^snapshot_id,
        join: quarantine_record in QuarantineRecordSchema,
        on: quarantine_record.id == snapshot_quarantine.quarantine_record_id,
        order_by: [asc: quarantine_record.id],
        select: quarantine_record
      )
    )
    |> Enum.map(&quarantine_to_core/1)
  end

  @spec duplicate_groups(String.t()) :: [DuplicateGroup.t()]
  def duplicate_groups(snapshot_id) do
    case Repo.get(CorpusSnapshot, snapshot_id) do
      nil ->
        []

      snapshot ->
        Repo.all(
          from(group in DuplicateGroupSchema,
            where: group.id in ^snapshot.duplicate_group_ids,
            order_by: [asc: group.id]
          )
        )
        |> Enum.map(&duplicate_group_to_core/1)
    end
  end

  @spec provenance_summary(String.t()) :: {:ok, map()} | {:error, term()}
  def provenance_summary(canonical_record_id) do
    with %CanonicalRecordSchema{} = record <- Repo.get(CanonicalRecordSchema, canonical_record_id) do
      raw_records =
        Repo.all(
          from(raw_record in RawRecordSchema, where: raw_record.id in ^record.raw_record_ids)
        )

      hits =
        Repo.all(
          from(hit in RetrievalHitSchema,
            where: hit.id in ^Enum.map(raw_records, & &1.search_hit_id)
          )
        )

      retrieval_runs =
        Repo.all(
          from(run in RetrievalRunSchema,
            where: run.id in ^Enum.map(raw_records, & &1.retrieval_run_id)
          )
        )

      decisions =
        Repo.all(
          from(decision in QADecisionSchema,
            where:
              decision.canonical_record_id == ^canonical_record_id or
                decision.record_id == ^canonical_record_id,
            order_by: [asc: decision.inserted_at, asc: decision.id]
          )
        )

      snapshots =
        Repo.all(
          from(snapshot_record in SnapshotRecord,
            where: snapshot_record.canonical_record_id == ^canonical_record_id,
            join: snapshot in CorpusSnapshot,
            on: snapshot.id == snapshot_record.corpus_snapshot_id,
            order_by: [desc: snapshot.finalized_at],
            select: snapshot
          )
        )

      {:ok,
       %{
         canonical_record: canonical_record_to_core(record),
         raw_records: Enum.map(raw_records, &raw_record_summary/1),
         retrieval_hits: Enum.map(hits, &retrieval_hit_summary/1),
         retrieval_runs: retrieval_runs,
         decisions: Enum.map(decisions, &decision_to_core/1),
         snapshots: snapshots
       }}
    else
      nil -> {:error, {:missing_canonical_record, canonical_record_id}}
    end
  end

  defp persist_qa_graph(repo, raw_records, %QAResult{} = qa_result, opts) do
    with {:ok, persisted_raw_records} <- persist_raw_records(repo, raw_records, opts),
         {:ok, canonical_records} <- persist_canonical_records(repo, qa_result),
         {:ok, duplicate_groups} <- persist_duplicate_groups(repo, qa_result.duplicate_groups),
         {:ok, decisions} <- persist_decisions(repo, qa_result),
         {:ok, quarantine_records} <-
           persist_quarantine_records(repo, qa_result.quarantine, decisions) do
      {:ok,
       %{
         raw_records: persisted_raw_records,
         canonical_records: canonical_records,
         duplicate_groups: duplicate_groups,
         decisions: decisions,
         quarantine_records: quarantine_records,
         opts: opts
       }}
    end
  end

  defp persist_raw_records(repo, raw_records, opts) do
    Enum.reduce_while(raw_records, {:ok, []}, fn %RawRecord{} = raw_record, {:ok, acc} ->
      with {:ok, normalized_theme_id} <- resolve_normalized_theme_id(raw_record, opts),
           {:ok, search_hit_id, branch_id} <-
             resolve_search_hit_id(repo, raw_record, normalized_theme_id),
           {:ok, fetched_document_id} <-
             resolve_fetched_document_id(repo, raw_record.fetched_document),
           {:ok, _record} <-
             repo.insert(
               RawRecordSchema.changeset(%RawRecordSchema{}, %{
                 id: raw_record.id,
                 search_hit_id: search_hit_id,
                 fetched_document_id: fetched_document_id,
                 retrieval_run_id: raw_record.retrieval_run_id,
                 research_branch_id: branch_id,
                 normalized_theme_id: normalized_theme_id,
                 split_from_id: raw_record.split_from_id,
                 raw_fields: Json.normalize(raw_record.raw_fields)
               }),
               on_conflict: :nothing,
               conflict_target: :id
             ),
           {:ok, persisted_raw_record} <- fetch_required(repo, RawRecordSchema, raw_record.id) do
        {:cont, {:ok, [persisted_raw_record | acc]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> reverse_ok_list()
  end

  defp persist_canonical_records(repo, %QAResult{} = qa_result) do
    qa_result
    |> all_canonical_records()
    |> Enum.reduce_while({:ok, []}, fn %CanonicalRecord{} = record, {:ok, acc} ->
      case repo.insert(
             CanonicalRecordSchema.changeset(
               %CanonicalRecordSchema{},
               canonical_record_attrs(record)
             ),
             on_conflict: :nothing,
             conflict_target: :id
           ) do
        {:ok, _schema} ->
          case fetch_required(repo, CanonicalRecordSchema, record.id) do
            {:ok, persisted} -> {:cont, {:ok, [persisted | acc]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> reverse_ok_list()
  end

  defp persist_duplicate_groups(repo, duplicate_groups) do
    Enum.reduce_while(duplicate_groups, {:ok, []}, fn %DuplicateGroup{} = duplicate_group,
                                                      {:ok, acc} ->
      case repo.insert(
             DuplicateGroupSchema.changeset(%DuplicateGroupSchema{}, %{
               id: duplicate_group.id,
               canonical_record_id: duplicate_group.canonical_record_id,
               representative_record_id: duplicate_group.representative_record_id,
               member_record_ids: duplicate_group.member_record_ids,
               member_raw_record_ids: duplicate_group.member_raw_record_ids,
               match_reasons: Json.normalize(duplicate_group.match_reasons),
               merge_strategy: Atom.to_string(duplicate_group.merge_strategy)
             }),
             on_conflict: :nothing,
             conflict_target: :id
           ) do
        {:ok, _record} ->
          case fetch_required(repo, DuplicateGroupSchema, duplicate_group.id) do
            {:ok, persisted} -> {:cont, {:ok, [persisted | acc]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> reverse_ok_list()
  end

  defp persist_decisions(repo, %QAResult{} = qa_result) do
    decisions = qa_result.decision_log ++ qa_result.discard_log

    Enum.reduce_while(decisions, {:ok, %{}}, fn %AcceptanceDecision{} = decision, {:ok, acc} ->
      decision_id = decision_id(decision)

      case repo.insert(
             QADecisionSchema.changeset(%QADecisionSchema{}, %{
               id: decision_id,
               record_id: decision.record_id,
               canonical_record_id: decision.canonical_record_id,
               stage: Atom.to_string(decision.stage),
               action: Atom.to_string(decision.action),
               classification: decision.classification && Atom.to_string(decision.classification),
               reason_codes: Enum.map(decision.reason_codes, &Atom.to_string/1),
               score_snapshot: Json.normalize(decision.score_snapshot),
               details: Json.normalize(decision.details),
               duplicate_group_id: decision.duplicate_group_id
             }),
             on_conflict: :nothing,
             conflict_target: :id
           ) do
        {:ok, _record} ->
          case fetch_required(repo, QADecisionSchema, decision_id) do
            {:ok, persisted} -> {:cont, {:ok, Map.put(acc, decision_id, persisted)}}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp persist_quarantine_records(repo, quarantine_records, decisions) do
    Enum.reduce_while(quarantine_records, {:ok, []}, fn %QuarantineRecord{} = quarantine_record,
                                                        {:ok, acc} ->
      decision_id = decision_id(quarantine_record.decision)

      with {:ok, persisted_decision} <-
             fetch_map(decisions, decision_id, :missing_quarantine_decision),
           {:ok, _record} <-
             repo.insert(
               QuarantineRecordSchema.changeset(%QuarantineRecordSchema{}, %{
                 id: quarantine_record.id,
                 decision_id: persisted_decision.id,
                 canonical_record_id:
                   quarantine_record.canonical_record && quarantine_record.canonical_record.id,
                 raw_record_ids: quarantine_record.raw_record_ids,
                 reason_codes: Enum.map(quarantine_record.reason_codes, &Atom.to_string/1),
                 candidate_record_ids: Enum.map(quarantine_record.candidate_records, & &1.id),
                 details: Json.normalize(quarantine_record.details)
               }),
               on_conflict: :nothing,
               conflict_target: :id
             ),
           {:ok, persisted_record} <-
             fetch_required(repo, QuarantineRecordSchema, quarantine_record.id) do
        {:cont, {:ok, [persisted_record | acc]}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> reverse_ok_list()
  end

  defp persist_snapshot(repo, persisted, %QAResult{} = qa_result, opts) do
    normalized_theme_ids =
      persisted.raw_records
      |> Enum.map(& &1.normalized_theme_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    branch_ids =
      persisted.raw_records
      |> Enum.map(& &1.research_branch_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    retrieval_run_ids =
      persisted.raw_records
      |> Enum.map(& &1.retrieval_run_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()

    duplicate_group_ids = Enum.map(persisted.duplicate_groups, & &1.id) |> Enum.sort()
    label = Keyword.get(opts, :label, "corpus snapshot")

    snapshot_id =
      ArtifactId.build("corpus_snapshot", %{
        label: label,
        normalized_theme_ids: normalized_theme_ids,
        branch_ids: branch_ids,
        retrieval_run_ids: retrieval_run_ids,
        duplicate_group_ids: duplicate_group_ids,
        accepted_core_ids: Enum.map(qa_result.accepted_core, & &1.id),
        accepted_analog_ids: Enum.map(qa_result.accepted_analog, & &1.id),
        background_ids: Enum.map(qa_result.background, & &1.id),
        quarantine_ids: Enum.map(qa_result.quarantine, & &1.id),
        discard_ids: Enum.map(qa_result.discard_log, & &1.record_id)
      })

    with {:ok, _snapshot} <-
           repo.insert(
             CorpusSnapshot.changeset(%CorpusSnapshot{}, %{
               id: snapshot_id,
               label: label,
               finalized_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
               normalized_theme_ids: normalized_theme_ids,
               branch_ids: branch_ids,
               retrieval_run_ids: retrieval_run_ids,
               duplicate_group_ids: duplicate_group_ids,
               accepted_core_count: length(qa_result.accepted_core),
               accepted_analog_count: length(qa_result.accepted_analog),
               background_count: length(qa_result.background),
               quarantine_count: length(qa_result.quarantine),
               discard_count: length(qa_result.discard_log),
               qa_summary: Json.normalize(qa_result.qa_decision_summary),
               duplicate_summary: %{"count" => length(qa_result.duplicate_groups)},
               quarantine_summary: %{
                 "count" => length(qa_result.quarantine),
                 "reason_codes" =>
                   qa_result.quarantine
                   |> Enum.flat_map(
                     &Enum.map(&1.reason_codes, fn code -> Atom.to_string(code) end)
                   )
                   |> Enum.uniq()
                   |> Enum.sort()
               },
               discard_summary: %{"count" => length(qa_result.discard_log)},
               source_lineage: %{
                 "normalized_theme_ids" => normalized_theme_ids,
                 "branch_ids" => branch_ids,
                 "retrieval_run_ids" => retrieval_run_ids,
                 "raw_record_ids" => Enum.map(persisted.raw_records, & &1.id)
               }
             }),
             on_conflict: :nothing,
             conflict_target: :id
           ),
         {:ok, snapshot} <- fetch_required(repo, CorpusSnapshot, snapshot_id),
         :ok <- persist_snapshot_records(repo, snapshot.id, qa_result, persisted.decisions),
         :ok <-
           persist_snapshot_quarantines(
             repo,
             snapshot.id,
             qa_result.quarantine,
             persisted.decisions
           ) do
      {:ok, snapshot}
    end
  end

  defp persist_snapshot_records(repo, snapshot_id, %QAResult{} = qa_result, decisions) do
    records =
      [
        {:accepted_core, qa_result.accepted_core},
        {:accepted_analog, qa_result.accepted_analog},
        {:background, qa_result.background}
      ]

    Enum.reduce_while(records, :ok, fn {classification, records}, :ok ->
      case Enum.reduce_while(records, :ok, fn %CanonicalRecord{} = record, :ok ->
             inclusion_reason = inclusion_reason(record, classification)

             snapshot_record_id =
               ArtifactId.build("snapshot_record", %{
                 snapshot_id: snapshot_id,
                 record_id: record.id,
                 classification: classification
               })

             case repo.insert(
                    SnapshotRecord.changeset(%SnapshotRecord{}, %{
                      id: snapshot_record_id,
                      corpus_snapshot_id: snapshot_id,
                      canonical_record_id: record.id,
                      qa_decision_id:
                        classification_decision_id(record, classification, decisions),
                      duplicate_group_id: inclusion_reason["duplicate_group_id"],
                      classification: Atom.to_string(classification),
                      inclusion_reason: inclusion_reason
                    }),
                    on_conflict: :nothing,
                    conflict_target: [:corpus_snapshot_id, :canonical_record_id, :classification]
                  ) do
               {:ok, _record} -> {:cont, :ok}
               {:error, reason} -> {:halt, {:error, reason}}
             end
           end) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp persist_snapshot_quarantines(repo, snapshot_id, quarantine_records, decisions) do
    Enum.reduce_while(quarantine_records, :ok, fn %QuarantineRecord{} = quarantine_record, :ok ->
      snapshot_quarantine_id =
        ArtifactId.build("snapshot_quarantine", %{
          snapshot_id: snapshot_id,
          quarantine_record_id: quarantine_record.id
        })

      case repo.insert(
             SnapshotQuarantine.changeset(%SnapshotQuarantine{}, %{
               id: snapshot_quarantine_id,
               corpus_snapshot_id: snapshot_id,
               quarantine_record_id: quarantine_record.id,
               qa_decision_id:
                 classification_decision_id(quarantine_record.decision, :quarantine, decisions),
               reason_codes: Enum.map(quarantine_record.reason_codes, &Atom.to_string/1)
             }),
             on_conflict: :nothing,
             conflict_target: [:corpus_snapshot_id, :quarantine_record_id]
           ) do
        {:ok, _record} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp snapshot_records(snapshot_id, classification)
       when classification in [:accepted_core, :accepted_analog, :background] do
    Repo.all(
      from(snapshot_record in SnapshotRecord,
        where:
          snapshot_record.corpus_snapshot_id == ^snapshot_id and
            snapshot_record.classification == ^Atom.to_string(classification),
        join: record in CanonicalRecordSchema,
        on: record.id == snapshot_record.canonical_record_id,
        order_by: [asc: record.canonical_title, asc: record.id],
        select: record
      )
    )
    |> Enum.map(&canonical_record_to_core/1)
  end

  defp resolve_normalized_theme_id(%RawRecord{theme: nil}, opts) do
    case Keyword.fetch(opts, :normalized_theme_id) do
      {:ok, normalized_theme_id} -> {:ok, normalized_theme_id}
      :error -> {:error, :missing_normalized_theme_id}
    end
  end

  defp resolve_normalized_theme_id(%RawRecord{theme: theme}, _opts),
    do: {:ok, Themes.normalized_theme_id(theme)}

  defp resolve_search_hit_id(repo, %RawRecord{} = raw_record, normalized_theme_id) do
    with %NormalizedSearchHit{} = hit <- raw_record.search_hit,
         {:ok, query_id} <- resolve_query_id(repo, normalized_theme_id, hit.query),
         branch_id = resolve_branch_id(normalized_theme_id, raw_record, hit.query),
         hit_id <- hit_id(raw_record.retrieval_run_id, query_id, hit),
         %RetrievalHitSchema{} <- repo.get(RetrievalHitSchema, hit_id) do
      {:ok, hit_id, branch_id}
    else
      nil -> {:error, {:missing_retrieval_hit, raw_record.id}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_query_id(repo, normalized_theme_id, %SearchQuery{} = query) do
    query_id = Branches.generated_query_id(normalized_theme_id, query)

    case repo.get(GeneratedQuery, query_id) do
      nil -> {:error, {:missing_generated_query, query_id, query.text}}
      _record -> {:ok, query_id}
    end
  end

  defp resolve_branch_id(normalized_theme_id, %RawRecord{branch: %Branch{} = branch}, _query) do
    Branches.branch_id(normalized_theme_id, branch)
  end

  defp resolve_branch_id(normalized_theme_id, %RawRecord{}, %SearchQuery{} = query) do
    Branches.branch_id(normalized_theme_id, query)
  end

  defp resolve_fetched_document_id(_repo, nil), do: {:ok, nil}

  defp resolve_fetched_document_id(repo, %FetchedDocument{} = fetched_document) do
    fetched_document_id =
      ArtifactId.build("fetched_document", %{
        url: fetched_document.url,
        content_fingerprint: ArtifactId.fingerprint(fetched_document.content)
      })

    content_fingerprint = ArtifactId.fingerprint(fetched_document.content)

    existing_document =
      repo.one(
        from(document in FetchedDocumentSchema,
          where:
            document.id == ^fetched_document_id or
              document.url == ^fetched_document.url or
              document.content_fingerprint == ^content_fingerprint
        )
      )

    if existing_document do
      {:ok, existing_document.id}
    else
      changeset =
        %{
          id: fetched_document_id,
          url: fetched_document.url,
          content: fetched_document.content,
          content_format: Atom.to_string(fetched_document.content_format),
          title: fetched_document.title,
          fetched_at: fetched_document.fetched_at,
          content_fingerprint: content_fingerprint
        }
        |> maybe_put(:raw_payload, Json.normalize(fetched_document.raw_payload))
        |> then(&FetchedDocumentSchema.changeset(%FetchedDocumentSchema{}, &1))

      case repo.insert(changeset, on_conflict: :nothing, conflict_target: :id) do
        {:ok, _record} -> {:ok, fetched_document_id}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp canonical_record_attrs(%CanonicalRecord{} = record) do
    %{
      id: record.id,
      canonical_title: record.canonical_title,
      canonical_citation: record.canonical_citation,
      canonical_url: record.canonical_url,
      year: record.year,
      authors: record.authors,
      source_type: record.source_type && Atom.to_string(record.source_type),
      doi: record.identifiers.doi,
      arxiv: record.identifiers.arxiv,
      ssrn: record.identifiers.ssrn,
      nber: record.identifiers.nber,
      osf: record.identifiers.osf,
      source_url: record.identifiers.url,
      abstract: record.abstract,
      content_excerpt: record.content_excerpt,
      methodology_summary: record.methodology_summary,
      findings_summary: record.findings_summary,
      limitations_summary: record.limitations_summary,
      direct_product_implication: record.direct_product_implication,
      market_type: record.market_type,
      classification: record.classification && Atom.to_string(record.classification),
      formula_completeness_status: Atom.to_string(record.formula_completeness_status),
      relevance_score: record.relevance_score,
      evidence_strength_score: record.evidence_strength_score,
      transferability_score: record.transferability_score,
      citation_quality_score: record.citation_quality_score,
      formula_actionability_score: record.formula_actionability_score,
      external_validity_risk: Atom.to_string(record.external_validity_risk),
      venue_specificity_flag: record.venue_specificity_flag,
      raw_record_ids: record.raw_record_ids,
      normalized_fields: Json.normalize(record.normalized_fields),
      provenance_providers:
        Enum.map(record.source_provenance_summary.providers, &Atom.to_string/1),
      provenance_retrieval_run_ids: record.source_provenance_summary.retrieval_run_ids,
      provenance_raw_record_ids: record.source_provenance_summary.raw_record_ids,
      provenance_query_texts: record.source_provenance_summary.query_texts,
      provenance_source_urls: record.source_provenance_summary.source_urls,
      provenance_branch_kinds:
        Enum.map(record.source_provenance_summary.branch_kinds, &Atom.to_string/1),
      provenance_branch_labels: record.source_provenance_summary.branch_labels,
      provenance_merged_from_canonical_ids:
        record.source_provenance_summary.merged_from_canonical_ids
    }
  end

  defp canonical_record_to_core(%CanonicalRecordSchema{} = record) do
    %CanonicalRecord{
      id: record.id,
      canonical_title: record.canonical_title,
      canonical_citation: record.canonical_citation,
      canonical_url: record.canonical_url,
      year: record.year,
      authors: record.authors,
      source_type: record.source_type && String.to_existing_atom(record.source_type),
      identifiers: %SourceIdentifiers{
        doi: record.doi,
        arxiv: record.arxiv,
        ssrn: record.ssrn,
        nber: record.nber,
        osf: record.osf,
        url: record.source_url
      },
      abstract: record.abstract,
      content_excerpt: record.content_excerpt,
      methodology_summary: record.methodology_summary,
      findings_summary: record.findings_summary,
      limitations_summary: record.limitations_summary,
      direct_product_implication: record.direct_product_implication,
      market_type: record.market_type,
      classification: record.classification && String.to_existing_atom(record.classification),
      formula_completeness_status: String.to_existing_atom(record.formula_completeness_status),
      source_provenance_summary: %SourceProvenanceSummary{
        providers: Enum.map(record.provenance_providers, &String.to_existing_atom/1),
        retrieval_run_ids: record.provenance_retrieval_run_ids,
        raw_record_ids: record.provenance_raw_record_ids,
        query_texts: record.provenance_query_texts,
        source_urls: record.provenance_source_urls,
        branch_kinds: Enum.map(record.provenance_branch_kinds, &String.to_existing_atom/1),
        branch_labels: record.provenance_branch_labels,
        merged_from_canonical_ids: record.provenance_merged_from_canonical_ids
      },
      relevance_score: record.relevance_score,
      evidence_strength_score: record.evidence_strength_score,
      transferability_score: record.transferability_score,
      citation_quality_score: record.citation_quality_score,
      formula_actionability_score: record.formula_actionability_score,
      external_validity_risk: String.to_existing_atom(record.external_validity_risk),
      venue_specificity_flag: record.venue_specificity_flag,
      raw_record_ids: record.raw_record_ids,
      normalized_fields: record.normalized_fields,
      qa_decisions: load_decisions_for_record(record.id)
    }
  end

  defp duplicate_group_to_core(%DuplicateGroupSchema{} = group) do
    %DuplicateGroup{
      id: group.id,
      canonical_record_id: group.canonical_record_id,
      representative_record_id: group.representative_record_id,
      member_record_ids: group.member_record_ids,
      member_raw_record_ids: group.member_raw_record_ids,
      match_reasons: group.match_reasons,
      merge_strategy: String.to_existing_atom(group.merge_strategy),
      decisions: load_duplicate_group_decisions(group.id)
    }
  end

  defp quarantine_to_core(%QuarantineRecordSchema{} = quarantine_record) do
    canonical_record =
      quarantine_record.canonical_record_id &&
        Repo.get(CanonicalRecordSchema, quarantine_record.canonical_record_id)

    %QuarantineRecord{
      id: quarantine_record.id,
      raw_record_ids: quarantine_record.raw_record_ids,
      reason_codes: Enum.map(quarantine_record.reason_codes, &String.to_existing_atom/1),
      decision: Repo.get!(QADecisionSchema, quarantine_record.decision_id) |> decision_to_core(),
      canonical_record: canonical_record && canonical_record_to_core(canonical_record),
      candidate_records:
        Repo.all(
          from(record in CanonicalRecordSchema,
            where: record.id in ^quarantine_record.candidate_record_ids
          )
        )
        |> Enum.map(&canonical_record_to_core/1),
      details: quarantine_record.details
    }
  end

  defp decision_to_core(%QADecisionSchema{} = decision) do
    %AcceptanceDecision{
      record_id: decision.record_id,
      canonical_record_id: decision.canonical_record_id,
      stage: String.to_existing_atom(decision.stage),
      action: String.to_existing_atom(decision.action),
      classification: decision.classification && String.to_existing_atom(decision.classification),
      reason_codes: Enum.map(decision.reason_codes, &String.to_existing_atom/1),
      score_snapshot: decision.score_snapshot,
      details: decision.details,
      duplicate_group_id: decision.duplicate_group_id
    }
  end

  defp load_decisions_for_record(record_id) do
    Repo.all(
      from(decision in QADecisionSchema,
        where:
          decision.canonical_record_id == ^record_id or
            decision.record_id == ^record_id,
        order_by: [asc: decision.inserted_at, asc: decision.id]
      )
    )
    |> Enum.map(&decision_to_core/1)
  end

  defp load_duplicate_group_decisions(group_id) do
    Repo.all(from(decision in QADecisionSchema, where: decision.duplicate_group_id == ^group_id))
    |> Enum.map(&decision_to_core/1)
  end

  defp inclusion_reason(%CanonicalRecord{} = record, classification) do
    %{
      "classification" => Atom.to_string(classification),
      "reason_codes" =>
        record.qa_decisions
        |> Enum.filter(&(&1.classification == classification))
        |> Enum.flat_map(
          &Enum.map(&1.reason_codes, fn reason_code -> Atom.to_string(reason_code) end)
        )
        |> Enum.uniq()
        |> Enum.sort(),
      "duplicate_group_id" =>
        record.qa_decisions
        |> Enum.find_value(fn decision -> decision.duplicate_group_id end),
      "raw_record_ids" => record.raw_record_ids
    }
  end

  defp classification_decision_id(%CanonicalRecord{} = record, classification, decisions) do
    record.qa_decisions
    |> Enum.find(fn decision ->
      decision.classification == classification and
        decision.action in [:accepted, :downgraded, :quarantined]
    end)
    |> case do
      nil ->
        nil

      decision ->
        decision_id = decision_id(decision)
        Map.get(decisions, decision_id) && decision_id
    end
  end

  defp classification_decision_id(%AcceptanceDecision{} = decision, _classification, decisions) do
    persisted_decision = Map.get(decisions, decision_id(decision))
    persisted_decision && persisted_decision.id
  end

  defp decision_id(%AcceptanceDecision{} = decision) do
    ArtifactId.build("qa_decision", %{
      record_id: decision.record_id,
      canonical_record_id: decision.canonical_record_id,
      stage: decision.stage,
      action: decision.action,
      classification: decision.classification,
      reason_codes: decision.reason_codes,
      score_snapshot: decision.score_snapshot,
      details: decision.details,
      duplicate_group_id: decision.duplicate_group_id
    })
  end

  defp all_canonical_records(%QAResult{} = qa_result) do
    (qa_result.accepted_core ++
       qa_result.accepted_analog ++
       qa_result.background ++
       Enum.flat_map(qa_result.quarantine, fn quarantine_record ->
         Enum.reject(
           [quarantine_record.canonical_record | quarantine_record.candidate_records],
           &is_nil/1
         )
       end))
    |> Enum.uniq_by(& &1.id)
  end

  defp raw_record_summary(%RawRecordSchema{} = raw_record) do
    %{
      id: raw_record.id,
      search_hit_id: raw_record.search_hit_id,
      fetched_document_id: raw_record.fetched_document_id,
      retrieval_run_id: raw_record.retrieval_run_id,
      research_branch_id: raw_record.research_branch_id,
      normalized_theme_id: raw_record.normalized_theme_id,
      split_from_id: raw_record.split_from_id,
      raw_fields: raw_record.raw_fields
    }
  end

  defp retrieval_hit_summary(%RetrievalHitSchema{} = hit) do
    %{
      id: hit.id,
      provider: hit.provider,
      search_request_id: hit.search_request_id,
      generated_query_id: hit.generated_query_id,
      title: hit.title,
      url: hit.url,
      fetch_status: hit.fetch_status
    }
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

  defp fetch_required(repo, schema, id) do
    case repo.get(schema, id) do
      nil -> {:error, {:missing_record, schema, id}}
      record -> {:ok, record}
    end
  end

  defp maybe_put(attrs, _key, nil), do: attrs
  defp maybe_put(attrs, key, value), do: Map.put(attrs, key, value)

  defp fetch_map(map, key, label) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {label, key}}
    end
  end

  defp reverse_ok_list({:ok, list}), do: {:ok, Enum.reverse(list)}
  defp reverse_ok_list(other), do: other

  defp unwrap_transaction({:ok, value}), do: {:ok, value}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}
end
