defmodule ResearchStore.Repo.Migrations.BuildEvidenceStoreRegistry do
  use Ecto.Migration

  def change do
    create table(:research_themes, primary_key: false) do
      add :id, :string, primary_key: true
      add :raw_text, :text, null: false
      add :source, :string
      add :content_hash, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:research_themes, [:content_hash])

    create table(:normalized_themes, primary_key: false) do
      add :id, :string, primary_key: true

      add :research_theme_id,
          references(:research_themes, type: :string, on_delete: :restrict),
          null: false

      add :original_input, :text, null: false
      add :normalized_text, :text, null: false
      add :topic, :string, null: false
      add :objective_description, :text
      add :notes, :text
      add :domain_hints, {:array, :string}, null: false, default: []
      add :mechanism_hints, {:array, :string}, null: false, default: []
      add :constraints, {:array, :map}, null: false, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create index(:normalized_themes, [:research_theme_id])

    create table(:research_branches, primary_key: false) do
      add :id, :string, primary_key: true

      add :normalized_theme_id,
          references(:normalized_themes, type: :string, on_delete: :restrict),
          null: false

      add :kind, :string, null: false
      add :label, :string, null: false
      add :rationale, :text, null: false
      add :theme_relation, :text, null: false
      add :source_targeting_rationale, :text
      add :preferred_source_families, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create index(:research_branches, [:normalized_theme_id])
    create unique_index(:research_branches, [:normalized_theme_id, :kind, :label])

    create constraint(:research_branches, :research_branches_kind_check,
             check: "kind in ('direct', 'narrower', 'broader', 'analog', 'mechanism', 'method')"
           )

    create table(:query_families, primary_key: false) do
      add :id, :string, primary_key: true

      add :research_branch_id,
          references(:research_branches, type: :string, on_delete: :restrict),
          null: false

      add :kind, :string, null: false
      add :rationale, :text, null: false
      add :source_families, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create index(:query_families, [:research_branch_id])
    create unique_index(:query_families, [:research_branch_id, :kind, :rationale])

    create constraint(:query_families, :query_families_kind_check,
             check:
               "kind in ('precision', 'recall', 'synonym_alias', 'literature_format', 'venue_specific', 'source_scoped')"
           )

    create table(:generated_queries, primary_key: false) do
      add :id, :string, primary_key: true

      add :research_branch_id,
          references(:research_branches, type: :string, on_delete: :restrict),
          null: false

      add :text, :text, null: false
      add :scope_type, :string, null: false, default: "generic"
      add :source_family, :string
      add :scoped_pattern, :text
      add :branch_kind, :string
      add :branch_label, :string
      add :source_hints, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec)
    end

    create index(:generated_queries, [:research_branch_id])
    create unique_index(:generated_queries, [:research_branch_id, :text, :scope_type, :source_family])

    create constraint(:generated_queries, :generated_queries_scope_type_check,
             check: "scope_type in ('generic', 'source_scoped')"
           )

    create table(:query_family_queries, primary_key: false) do
      add :id, :string, primary_key: true

      add :query_family_id,
          references(:query_families, type: :string, on_delete: :delete_all),
          null: false

      add :generated_query_id,
          references(:generated_queries, type: :string, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:query_family_queries, [:query_family_id, :generated_query_id])

    create table(:retrieval_runs, primary_key: false) do
      add :id, :string, primary_key: true
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :search_request_count, :integer, null: false, default: 0
      add :provider_result_count, :integer, null: false, default: 0
      add :fetch_request_count, :integer, null: false, default: 0
      add :provider_error_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create table(:retrieval_search_requests, primary_key: false) do
      add :id, :string, primary_key: true

      add :retrieval_run_id,
          references(:retrieval_runs, type: :string, on_delete: :restrict),
          null: false

      add :generated_query_id,
          references(:generated_queries, type: :string, on_delete: :restrict),
          null: false

      add :provider, :string, null: false
      add :max_results, :integer

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:retrieval_search_requests, [:retrieval_run_id])
    create index(:retrieval_search_requests, [:generated_query_id])
    create unique_index(:retrieval_search_requests, [:retrieval_run_id, :generated_query_id, :provider])

    create table(:fetched_documents, primary_key: false) do
      add :id, :string, primary_key: true
      add :url, :text, null: false
      add :content, :text, null: false
      add :content_format, :string, null: false
      add :title, :text
      add :raw_payload, :map
      add :fetched_at, :utc_datetime_usec
      add :content_fingerprint, :string, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:fetched_documents, [:url])
    create unique_index(:fetched_documents, [:content_fingerprint])

    create table(:normalized_retrieval_hits, primary_key: false) do
      add :id, :string, primary_key: true

      add :retrieval_run_id,
          references(:retrieval_runs, type: :string, on_delete: :restrict),
          null: false

      add :search_request_id,
          references(:retrieval_search_requests, type: :string, on_delete: :restrict),
          null: false

      add :generated_query_id,
          references(:generated_queries, type: :string, on_delete: :restrict),
          null: false

      add :fetched_document_id,
          references(:fetched_documents, type: :string, on_delete: :nilify_all)

      add :provider, :string, null: false
      add :rank, :integer, null: false
      add :title, :text, null: false
      add :url, :text, null: false
      add :snippet, :text
      add :raw_payload, :map
      add :fetch_status, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:normalized_retrieval_hits, [:retrieval_run_id])
    create index(:normalized_retrieval_hits, [:search_request_id])
    create index(:normalized_retrieval_hits, [:generated_query_id])
    create unique_index(:normalized_retrieval_hits, [:retrieval_run_id, :generated_query_id, :provider, :rank, :url])

    create table(:raw_corpus_records, primary_key: false) do
      add :id, :string, primary_key: true

      add :search_hit_id,
          references(:normalized_retrieval_hits, type: :string, on_delete: :restrict),
          null: false

      add :fetched_document_id,
          references(:fetched_documents, type: :string, on_delete: :nilify_all)

      add :retrieval_run_id,
          references(:retrieval_runs, type: :string, on_delete: :restrict)

      add :research_branch_id,
          references(:research_branches, type: :string, on_delete: :restrict)

      add :normalized_theme_id,
          references(:normalized_themes, type: :string, on_delete: :restrict)

      add :split_from_id,
          references(:raw_corpus_records, type: :string, on_delete: :nilify_all)

      add :raw_fields, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:raw_corpus_records, [:search_hit_id])
    create index(:raw_corpus_records, [:retrieval_run_id])
    create index(:raw_corpus_records, [:research_branch_id])
    create index(:raw_corpus_records, [:normalized_theme_id])

    create table(:canonical_corpus_records, primary_key: false) do
      add :id, :string, primary_key: true
      add :canonical_title, :text, null: false
      add :canonical_citation, :text
      add :canonical_url, :text
      add :year, :integer
      add :authors, {:array, :string}, null: false, default: []
      add :source_type, :string
      add :doi, :string
      add :arxiv, :string
      add :ssrn, :string
      add :nber, :string
      add :osf, :string
      add :source_url, :text
      add :abstract, :text
      add :content_excerpt, :text
      add :methodology_summary, :text
      add :findings_summary, :text
      add :limitations_summary, :text
      add :direct_product_implication, :text
      add :market_type, :string
      add :classification, :string
      add :formula_completeness_status, :string, null: false
      add :relevance_score, :integer, null: false, default: 0
      add :evidence_strength_score, :integer, null: false, default: 0
      add :transferability_score, :integer, null: false, default: 0
      add :citation_quality_score, :integer, null: false, default: 0
      add :formula_actionability_score, :integer, null: false, default: 0
      add :external_validity_risk, :string, null: false, default: "unknown"
      add :venue_specificity_flag, :boolean, null: false, default: false
      add :raw_record_ids, {:array, :string}, null: false, default: []
      add :normalized_fields, :map, null: false, default: %{}
      add :provenance_providers, {:array, :string}, null: false, default: []
      add :provenance_retrieval_run_ids, {:array, :string}, null: false, default: []
      add :provenance_raw_record_ids, {:array, :string}, null: false, default: []
      add :provenance_query_texts, {:array, :string}, null: false, default: []
      add :provenance_source_urls, {:array, :string}, null: false, default: []
      add :provenance_branch_kinds, {:array, :string}, null: false, default: []
      add :provenance_branch_labels, {:array, :string}, null: false, default: []
      add :provenance_merged_from_canonical_ids, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:canonical_corpus_records, [:classification])
    create unique_index(:canonical_corpus_records, [:canonical_url], where: "canonical_url is not null")

    create constraint(:canonical_corpus_records, :canonical_corpus_records_classification_check,
             check:
               "classification is null or classification in ('accepted_core', 'accepted_analog', 'background', 'quarantine', 'discard')"
           )

    create constraint(:canonical_corpus_records, :canonical_corpus_records_formula_status_check,
             check:
               "formula_completeness_status in ('exact', 'partial', 'referenced_only', 'none', 'unknown')"
           )

    create constraint(:canonical_corpus_records, :canonical_corpus_records_risk_check,
             check: "external_validity_risk in ('low', 'medium', 'high', 'unknown')"
           )

    create table(:duplicate_groups, primary_key: false) do
      add :id, :string, primary_key: true

      add :canonical_record_id,
          references(:canonical_corpus_records, type: :string, on_delete: :restrict),
          null: false

      add :representative_record_id, :string, null: false
      add :member_record_ids, {:array, :string}, null: false, default: []
      add :member_raw_record_ids, {:array, :string}, null: false, default: []
      add :match_reasons, {:array, :map}, null: false, default: []
      add :merge_strategy, :string, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:duplicate_groups, [:canonical_record_id])

    create table(:qa_decisions, primary_key: false) do
      add :id, :string, primary_key: true
      add :record_id, :string, null: false

      add :canonical_record_id,
          references(:canonical_corpus_records, type: :string, on_delete: :nilify_all)

      add :stage, :string, null: false
      add :action, :string, null: false
      add :classification, :string
      add :reason_codes, {:array, :string}, null: false, default: []
      add :score_snapshot, :map, null: false, default: %{}
      add :details, :map, null: false, default: %{}

      add :duplicate_group_id,
          references(:duplicate_groups, type: :string, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:qa_decisions, [:canonical_record_id])
    create index(:qa_decisions, [:duplicate_group_id])
    create index(:qa_decisions, [:record_id])

    create constraint(:qa_decisions, :qa_decisions_stage_check,
             check: "stage in ('conflation_detection', 'duplicate_grouping', 'classification')"
           )

    create constraint(:qa_decisions, :qa_decisions_action_check,
             check: "action in ('accepted', 'downgraded', 'quarantined', 'discarded', 'merged', 'split')"
           )

    create constraint(:qa_decisions, :qa_decisions_classification_check,
             check:
               "classification is null or classification in ('accepted_core', 'accepted_analog', 'background', 'quarantine', 'discard')"
           )

    create table(:quarantine_records, primary_key: false) do
      add :id, :string, primary_key: true

      add :decision_id,
          references(:qa_decisions, type: :string, on_delete: :restrict),
          null: false

      add :canonical_record_id,
          references(:canonical_corpus_records, type: :string, on_delete: :nilify_all)

      add :raw_record_ids, {:array, :string}, null: false, default: []
      add :reason_codes, {:array, :string}, null: false, default: []
      add :candidate_record_ids, {:array, :string}, null: false, default: []
      add :details, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:quarantine_records, [:decision_id])
    create index(:quarantine_records, [:canonical_record_id])

    create table(:corpus_snapshots, primary_key: false) do
      add :id, :string, primary_key: true
      add :label, :string
      add :finalized_at, :utc_datetime_usec, null: false
      add :normalized_theme_ids, {:array, :string}, null: false, default: []
      add :branch_ids, {:array, :string}, null: false, default: []
      add :retrieval_run_ids, {:array, :string}, null: false, default: []
      add :duplicate_group_ids, {:array, :string}, null: false, default: []
      add :accepted_core_count, :integer, null: false, default: 0
      add :accepted_analog_count, :integer, null: false, default: 0
      add :background_count, :integer, null: false, default: 0
      add :quarantine_count, :integer, null: false, default: 0
      add :discard_count, :integer, null: false, default: 0
      add :qa_summary, :map, null: false, default: %{}
      add :duplicate_summary, :map, null: false, default: %{}
      add :quarantine_summary, :map, null: false, default: %{}
      add :discard_summary, :map, null: false, default: %{}
      add :source_lineage, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:corpus_snapshots, [:finalized_at])

    create table(:corpus_snapshot_records, primary_key: false) do
      add :id, :string, primary_key: true

      add :corpus_snapshot_id,
          references(:corpus_snapshots, type: :string, on_delete: :delete_all),
          null: false

      add :canonical_record_id,
          references(:canonical_corpus_records, type: :string, on_delete: :restrict),
          null: false

      add :qa_decision_id,
          references(:qa_decisions, type: :string, on_delete: :nilify_all)

      add :duplicate_group_id,
          references(:duplicate_groups, type: :string, on_delete: :nilify_all)

      add :classification, :string, null: false
      add :inclusion_reason, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:corpus_snapshot_records, [:corpus_snapshot_id])
    create index(:corpus_snapshot_records, [:canonical_record_id])
    create unique_index(:corpus_snapshot_records, [:corpus_snapshot_id, :canonical_record_id, :classification])

    create constraint(:corpus_snapshot_records, :corpus_snapshot_records_classification_check,
             check: "classification in ('accepted_core', 'accepted_analog', 'background')"
           )

    create table(:corpus_snapshot_quarantines, primary_key: false) do
      add :id, :string, primary_key: true

      add :corpus_snapshot_id,
          references(:corpus_snapshots, type: :string, on_delete: :delete_all),
          null: false

      add :quarantine_record_id,
          references(:quarantine_records, type: :string, on_delete: :restrict),
          null: false

      add :qa_decision_id,
          references(:qa_decisions, type: :string, on_delete: :nilify_all)

      add :reason_codes, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:corpus_snapshot_quarantines, [:corpus_snapshot_id, :quarantine_record_id])
    create index(:corpus_snapshot_quarantines, [:corpus_snapshot_id])

    execute(
      """
      CREATE FUNCTION prevent_corpus_snapshot_update() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'corpus snapshots are immutable once finalized';
      END;
      $$ LANGUAGE plpgsql;
      """,
      "DROP FUNCTION IF EXISTS prevent_corpus_snapshot_update();"
    )

    execute(
      """
      CREATE TRIGGER corpus_snapshots_no_update
      BEFORE UPDATE OR DELETE ON corpus_snapshots
      FOR EACH ROW EXECUTE FUNCTION prevent_corpus_snapshot_update();
      """,
      "DROP TRIGGER IF EXISTS corpus_snapshots_no_update ON corpus_snapshots;"
    )
  end
end
