defmodule ResearchStore.Repo.Migrations.AddEvidenceDocumentParserTables do
  use Ecto.Migration

  def change do
    create table(:evidence_documents, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:source_uri, :text)
      add(:content_hash, :string, null: false)
      add(:mime_type, :string)
      add(:title, :text)
      add(:parser, :string)
      add(:parser_version, :string)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(unique_index(:evidence_documents, [:content_hash]))
    create(index(:evidence_documents, [:source_uri]))
    create(index(:evidence_documents, [:parser]))

    create table(:evidence_document_pages, primary_key: false) do
      add(:id, :string, primary_key: true)

      add(
        :evidence_document_id,
        references(:evidence_documents, type: :string, on_delete: :delete_all),
        null: false
      )

      add(:page_number, :integer, null: false)
      add(:text, :text)
      add(:text_hash, :string)
      add(:source, :string, null: false)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(unique_index(:evidence_document_pages, [:evidence_document_id, :page_number]))
    create(index(:evidence_document_pages, [:source]))

    create(
      constraint(:evidence_document_pages, :evidence_document_pages_page_number_check,
        check: "page_number > 0"
      )
    )

    create table(:evidence_spans, primary_key: false) do
      add(:id, :string, primary_key: true)

      add(
        :evidence_document_id,
        references(:evidence_documents, type: :string, on_delete: :delete_all),
        null: false
      )

      add(:page_number, :integer)
      add(:quote_text, :text, null: false)
      add(:quote_hash, :string, null: false)
      add(:source, :string, null: false)
      add(:source_ref, :string)
      add(:bboxes, {:array, :map}, null: false, default: [])
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:evidence_spans, [:evidence_document_id, :page_number]))
    create(index(:evidence_spans, [:source]))
    create(index(:evidence_spans, [:quote_hash]))

    create(
      constraint(:evidence_spans, :evidence_spans_page_number_check,
        check: "page_number is null or page_number > 0"
      )
    )

    create table(:evidence_formula_blocks, primary_key: false) do
      add(:id, :string, primary_key: true)

      add(
        :evidence_document_id,
        references(:evidence_documents, type: :string, on_delete: :delete_all),
        null: false
      )

      add(
        :evidence_span_id,
        references(:evidence_spans, type: :string, on_delete: :nilify_all)
      )

      add(:label, :string)
      add(:raw_text, :text, null: false)
      add(:normalized_text, :text)
      add(:latex, :text)
      add(:source, :string, null: false)
      add(:source_ref, :string)
      add(:page_numbers, {:array, :integer}, null: false, default: [])
      add(:bboxes, {:array, :map}, null: false, default: [])
      add(:confidence, :float)
      add(:parser, :string)
      add(:metadata, :map, null: false, default: %{})
      add(:ambiguity_markers, {:array, :string}, null: false, default: [])

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:evidence_formula_blocks, [:evidence_document_id]))
    create(index(:evidence_formula_blocks, [:evidence_span_id]))
    create(index(:evidence_formula_blocks, [:source]))
  end
end
