defmodule ResearchStore.Repo.Migrations.AddStrategyExtractionRegistryTables do
  use Ecto.Migration

  def change do
    create table(:strategy_extraction_runs, primary_key: false) do
      add :id, :string, primary_key: true

      add :corpus_snapshot_id,
          references(:corpus_snapshots, type: :string, on_delete: :restrict),
          null: false

      add :synthesis_run_id,
          references(:synthesis_runs, type: :string, on_delete: :restrict),
          null: false

      add :synthesis_artifact_id,
          references(:synthesis_artifacts, type: :string, on_delete: :restrict),
          null: false

      add :normalized_theme_id,
          references(:normalized_themes, type: :string, on_delete: :restrict)

      add :research_branch_id,
          references(:research_branches, type: :string, on_delete: :restrict)

      add :synthesis_profile_id, :string, null: false
      add :state, :string, null: false
      add :input_package, :map, null: false, default: %{}
      add :formula_request_spec, :map, null: false, default: %{}
      add :strategy_request_spec, :map, null: false, default: %{}
      add :provider_name, :string
      add :provider_model, :string
      add :provider_request_id, :string
      add :provider_response_id, :string
      add :provider_request_hash, :string
      add :provider_response_hash, :string
      add :provider_metadata, :map, null: false, default: %{}
      add :provider_failure, :map, null: false, default: %{}
      add :raw_provider_output, :map, null: false, default: %{}
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:strategy_extraction_runs, [:corpus_snapshot_id, :synthesis_profile_id])
    create index(:strategy_extraction_runs, [:synthesis_artifact_id])
    create index(:strategy_extraction_runs, [:synthesis_run_id])
    create index(:strategy_extraction_runs, [:normalized_theme_id, :synthesis_profile_id])
    create index(:strategy_extraction_runs, [:research_branch_id, :synthesis_profile_id])
    create index(:strategy_extraction_runs, [:state])

    create constraint(:strategy_extraction_runs, :strategy_extraction_runs_state_check,
             check:
               "state in ('pending', 'running', 'completed', 'provider_failed', 'validation_failed')"
           )

    create table(:strategy_validation_results, primary_key: false) do
      add :id, :string, primary_key: true

      add :strategy_extraction_run_id,
          references(:strategy_extraction_runs, type: :string, on_delete: :delete_all),
          null: false

      add :valid, :boolean, null: false, default: false
      add :fatal_errors, {:array, :map}, null: false, default: []
      add :warnings, {:array, :map}, null: false, default: []
      add :rejected_formulas, {:array, :map}, null: false, default: []
      add :rejected_candidates, {:array, :map}, null: false, default: []
      add :duplicate_groups, {:array, :map}, null: false, default: []
      add :accepted_formula_ids, {:array, :string}, null: false, default: []
      add :accepted_strategy_ids, {:array, :string}, null: false, default: []
      add :validated_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:strategy_validation_results, [:strategy_extraction_run_id])

    create table(:strategy_formula_candidates, primary_key: false) do
      add :id, :string, primary_key: true

      add :strategy_extraction_run_id,
          references(:strategy_extraction_runs, type: :string, on_delete: :delete_all),
          null: false

      add :corpus_snapshot_id,
          references(:corpus_snapshots, type: :string, on_delete: :restrict),
          null: false

      add :synthesis_artifact_id,
          references(:synthesis_artifacts, type: :string, on_delete: :restrict),
          null: false

      add :formula_text, :text, null: false
      add :exact, :boolean, null: false, default: false
      add :partial, :boolean, null: false, default: false
      add :blocked, :boolean, null: false, default: false
      add :role, :string, null: false
      add :symbol_glossary, :map, null: false, default: %{}
      add :source_section_ids, {:array, :string}, null: false, default: []
      add :source_section_headings, {:array, :string}, null: false, default: []
      add :supporting_citation_keys, {:array, :string}, null: false, default: []
      add :supporting_record_ids, {:array, :string}, null: false, default: []
      add :evidence_links, {:array, :map}, null: false, default: []
      add :notes, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:strategy_formula_candidates, [:strategy_extraction_run_id])
    create index(:strategy_formula_candidates, [:corpus_snapshot_id, :role])
    create index(:strategy_formula_candidates, [:synthesis_artifact_id])
    create index(:strategy_formula_candidates, [:blocked])

    create constraint(:strategy_formula_candidates, :strategy_formula_candidates_role_check,
             check:
               "role in ('calibration', 'execution', 'arbitrage_or_coherence', 'sizing', 'behavioral_adjustment', 'other')"
           )

    create table(:strategy_specs, primary_key: false) do
      add :id, :string, primary_key: true

      add :strategy_extraction_run_id,
          references(:strategy_extraction_runs, type: :string, on_delete: :delete_all),
          null: false

      add :corpus_snapshot_id,
          references(:corpus_snapshots, type: :string, on_delete: :restrict),
          null: false

      add :synthesis_run_id,
          references(:synthesis_runs, type: :string, on_delete: :restrict),
          null: false

      add :synthesis_artifact_id,
          references(:synthesis_artifacts, type: :string, on_delete: :restrict),
          null: false

      add :strategy_candidate_id, :string, null: false
      add :title, :string, null: false
      add :thesis, :text, null: false
      add :category, :string, null: false
      add :candidate_kind, :string, null: false
      add :market_or_domain_applicability, :text, null: false
      add :decision_rule, :map, null: false, default: %{}
      add :expected_edge_source, :text
      add :falsification_idea, :text
      add :readiness, :string, null: false
      add :evidence_strength, :string, null: false
      add :actionability, :string, null: false
      add :formula_ids, {:array, :string}, null: false, default: []
      add :required_features, {:array, :map}, null: false, default: []
      add :required_datasets, {:array, :map}, null: false, default: []
      add :execution_assumptions, {:array, :map}, null: false, default: []
      add :sizing_assumptions, {:array, :map}, null: false, default: []
      add :evidence_links, {:array, :map}, null: false, default: []
      add :conflicting_evidence_links, {:array, :map}, null: false, default: []
      add :validation_hints, {:array, :map}, null: false, default: []
      add :metric_hints, {:array, :map}, null: false, default: []
      add :notes, {:array, :string}, null: false, default: []
      add :blocked_by, {:array, :string}, null: false, default: []

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:strategy_specs, [:strategy_extraction_run_id])
    create index(:strategy_specs, [:corpus_snapshot_id, :readiness])
    create index(:strategy_specs, [:corpus_snapshot_id, :category])
    create index(:strategy_specs, [:synthesis_artifact_id, :readiness])
    create index(:strategy_specs, [:synthesis_run_id])
    create index(:strategy_specs, [:actionability])

    create constraint(:strategy_specs, :strategy_specs_category_check,
             check:
               "category in ('calibration_strategy', 'execution_strategy', 'coherence_arbitrage_strategy', 'sizing_strategy', 'behavioral_filter_strategy', 'analog_transfer_strategy', 'market_structure_strategy')"
           )

    create constraint(:strategy_specs, :strategy_specs_candidate_kind_check,
             check:
               "candidate_kind in ('directly_specified_strategy', 'formula_backed_incomplete_strategy', 'analog_transfer_candidate', 'speculative_not_backtestable')"
           )

    create constraint(:strategy_specs, :strategy_specs_readiness_check,
             check:
               "readiness in ('ready_for_backtest', 'needs_feature_build', 'needs_formula_completion', 'needs_data_mapping', 'reject')"
           )

    create constraint(:strategy_specs, :strategy_specs_evidence_strength_check,
             check: "evidence_strength in ('strong', 'moderate', 'weak', 'speculative')"
           )

    create constraint(:strategy_specs, :strategy_specs_actionability_check,
             check: "actionability in ('immediate', 'near_term', 'exploratory', 'background_only')"
           )
  end
end
