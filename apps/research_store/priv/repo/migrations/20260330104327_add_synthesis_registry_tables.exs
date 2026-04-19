defmodule ResearchStore.Repo.Migrations.AddSynthesisRegistryTables do
  use Ecto.Migration

  def change do
    create table(:synthesis_runs, primary_key: false) do
      add :id, :string, primary_key: true

      add :corpus_snapshot_id,
          references(:corpus_snapshots, type: :string, on_delete: :restrict),
          null: false

      add :normalized_theme_id,
          references(:normalized_themes, type: :string, on_delete: :nilify_all)

      add :research_branch_id,
          references(:research_branches, type: :string, on_delete: :nilify_all)

      add :profile_id, :string, null: false
      add :state, :string, null: false
      add :input_package, :map, null: false, default: %{}
      add :request_spec, :map, null: false, default: %{}
      add :provider_name, :string
      add :provider_model, :string
      add :provider_request_id, :string
      add :provider_response_id, :string
      add :provider_request_hash, :string
      add :provider_response_hash, :string
      add :provider_metadata, :map, null: false, default: %{}
      add :provider_failure, :map, null: false, default: %{}
      add :raw_provider_output, :text
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:synthesis_runs, [:corpus_snapshot_id, :profile_id])
    create index(:synthesis_runs, [:normalized_theme_id, :profile_id])
    create index(:synthesis_runs, [:research_branch_id, :profile_id])

    create constraint(:synthesis_runs, :synthesis_runs_state_check,
             check: "state in ('pending', 'running', 'completed', 'validation_failed', 'provider_failed')"
           )

    create table(:synthesis_validation_results, primary_key: false) do
      add :id, :string, primary_key: true

      add :synthesis_run_id,
          references(:synthesis_runs, type: :string, on_delete: :delete_all),
          null: false

      add :valid, :boolean, null: false, default: false
      add :structural_errors, {:array, :map}, null: false, default: []
      add :citation_errors, {:array, :map}, null: false, default: []
      add :formula_errors, {:array, :map}, null: false, default: []
      add :cited_keys, {:array, :string}, null: false, default: []
      add :allowed_keys, {:array, :string}, null: false, default: []
      add :unknown_keys, {:array, :string}, null: false, default: []
      add :metadata, :map, null: false, default: %{}
      add :validated_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:synthesis_validation_results, [:synthesis_run_id])

    create table(:synthesis_artifacts, primary_key: false) do
      add :id, :string, primary_key: true

      add :synthesis_run_id,
          references(:synthesis_runs, type: :string, on_delete: :delete_all),
          null: false

      add :corpus_snapshot_id,
          references(:corpus_snapshots, type: :string, on_delete: :restrict),
          null: false

      add :profile_id, :string, null: false
      add :format, :string, null: false
      add :content, :text, null: false
      add :section_headings, {:array, :string}, null: false, default: []
      add :cited_keys, {:array, :string}, null: false, default: []
      add :artifact_hash, :string, null: false
      add :summary, :map, null: false, default: %{}
      add :finalized_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:synthesis_artifacts, [:synthesis_run_id])
    create index(:synthesis_artifacts, [:corpus_snapshot_id, :profile_id])

    create constraint(:synthesis_artifacts, :synthesis_artifacts_format_check,
             check: "format in ('markdown')"
           )

    execute(
      """
      CREATE FUNCTION prevent_synthesis_artifact_update() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'synthesis artifacts are immutable once finalized';
      END;
      $$ LANGUAGE plpgsql;
      """,
      "DROP FUNCTION IF EXISTS prevent_synthesis_artifact_update();"
    )

    execute(
      """
      CREATE TRIGGER synthesis_artifacts_no_update
      BEFORE UPDATE OR DELETE ON synthesis_artifacts
      FOR EACH ROW EXECUTE FUNCTION prevent_synthesis_artifact_update();
      """,
      "DROP TRIGGER IF EXISTS synthesis_artifacts_no_update ON synthesis_artifacts;"
    )
  end
end
