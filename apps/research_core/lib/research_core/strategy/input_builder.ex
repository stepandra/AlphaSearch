defmodule ResearchCore.Strategy.InputBuilder do
  @moduledoc """
  Deterministically packages a validated synthesis artifact and finalized snapshot for strategy extraction.
  """

  alias ResearchCore.Corpus.{CanonicalRecord, SourceProvenanceSummary}
  alias ResearchCore.Canonical
  alias ResearchCore.Synthesis
  alias ResearchCore.Strategy.{Helpers, InputPackage, Section}

  @required_sections [
    :executive_summary,
    :ranked_important_papers_and_findings,
    :taxonomy_and_thematic_grouping,
    :reusable_formulas,
    :open_gaps,
    :next_prototype_recommendations
  ]

  @spec build(map(), map() | struct(), map() | struct(), map() | struct(), keyword()) ::
          {:ok, InputPackage.t()} | {:error, term()}
  def build(
        %{snapshot: snapshot} = bundle,
        synthesis_run,
        artifact,
        validation_result,
        opts \\ []
      ) do
    with :ok <- finalized_snapshot(snapshot),
         :ok <- validated_artifact(snapshot, synthesis_run, artifact, validation_result),
         {:ok, profile} <- Synthesis.profile(Helpers.fetch(synthesis_run, :profile_id)),
         {:ok, report_sections} <- parse_sections(artifact, profile),
         {:ok, resolved_records} <-
           resolve_records(bundle, synthesis_run, profile, report_sections),
         do: package(bundle, synthesis_run, artifact, report_sections, resolved_records, opts)
  end

  defp finalized_snapshot(%{finalized_at: %DateTime{}}), do: :ok
  defp finalized_snapshot(_snapshot), do: {:error, :snapshot_not_finalized}

  defp validated_artifact(snapshot, synthesis_run, artifact, validation_result) do
    cond do
      Helpers.fetch(validation_result, :valid?, false) != true ->
        {:error, :synthesis_artifact_not_validated}

      Helpers.fetch(artifact, :synthesis_run_id) != Helpers.fetch(synthesis_run, :id) ->
        {:error, :artifact_run_mismatch}

      Helpers.fetch(artifact, :corpus_snapshot_id) != snapshot.id ->
        {:error, :artifact_snapshot_mismatch}

      Helpers.fetch(synthesis_run, :corpus_snapshot_id) != snapshot.id ->
        {:error, :run_snapshot_mismatch}

      true ->
        :ok
    end
  end

  defp parse_sections(artifact, profile) do
    sections =
      artifact
      |> Helpers.fetch(:content, "")
      |> then(&Regex.scan(~r/^##\s+(.+?)\s*$\n(.*?)(?=^##\s+|\z)/ms, &1, capture: :all_but_first))
      |> Enum.with_index()
      |> Enum.map(fn {[heading, body], index} ->
        %Section{
          id: Helpers.slug(heading),
          heading: heading,
          body: String.trim(body),
          index: index,
          cited_keys:
            Helpers.extract_cited_keys(
              body,
              profile.citation_key_prefix,
              profile.citation_key_width
            )
        }
      end)

    missing_sections =
      @required_sections -- Enum.map(sections, & &1.id)

    if missing_sections == [] do
      {:ok, sections}
    else
      {:error, {:missing_extraction_sections, missing_sections}}
    end
  end

  defp resolve_records(bundle, synthesis_run, profile, report_sections) do
    cited_keys =
      report_sections
      |> Enum.flat_map(& &1.cited_keys)
      |> Enum.uniq()
      |> Enum.sort()

    snapshot_records = snapshot_records_by_id(bundle)

    with citation_lookup <- citation_lookup(snapshot_records, profile),
         citation_key_lookup <- invert_citation_lookup(citation_lookup),
         formula_lookup <- synthesis_formula_lookup(synthesis_run),
         {:ok, records} <-
           resolve_cited_records(
             cited_keys,
             snapshot_records,
             citation_key_lookup,
             formula_lookup,
             synthesis_run
           ) do
      if map_size(records) == 0 do
        {:error, :missing_synthesis_input_records}
      else
        {:ok, records}
      end
    end
  end

  defp resolve_cited_records(
         cited_keys,
         snapshot_records,
         citation_key_lookup,
         formula_lookup,
         synthesis_run
       ) do
    Enum.reduce_while(cited_keys, {:ok, %{}}, fn citation_key, {:ok, acc} ->
      with {:ok, record_id} <- fetch_snapshot_record_id(citation_key_lookup, citation_key),
           {:ok, {classification, %CanonicalRecord{} = snapshot_record}} <-
             fetch_snapshot_record(snapshot_records, record_id),
           formula_payload <- Map.get(formula_lookup, record_id) do
        record =
          normalize_record(
            snapshot_record,
            classification,
            citation_key,
            formula_payload,
            synthesis_run
          )

        {:cont, {:ok, Map.put(acc, citation_key, record)}}
      else
        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_record(
         snapshot_record,
         classification,
         citation_key,
         formula_payload,
         synthesis_run
       ) do
    provenance_reference = provenance_reference(snapshot_record, synthesis_run)
    formula = formula_payload(snapshot_record, formula_payload)

    %{
      record_id: snapshot_record.id,
      classification: classification,
      citation_key: citation_key,
      title: snapshot_record.canonical_title,
      citation: snapshot_record.canonical_citation,
      url: snapshot_record.canonical_url,
      year: snapshot_record.year,
      authors: snapshot_record.authors,
      source_type: snapshot_record.source_type,
      abstract: snapshot_record.abstract,
      methodology_summary: snapshot_record.methodology_summary,
      findings_summary: snapshot_record.findings_summary,
      limitations_summary: snapshot_record.limitations_summary,
      direct_product_implication: snapshot_record.direct_product_implication,
      formula: formula,
      provenance_reference: provenance_reference,
      scores: normalize_scores(snapshot_record),
      synthesis_run_id: Helpers.fetch(synthesis_run, :id)
    }
  end

  defp snapshot_records_by_id(bundle) do
    [
      {:accepted_core, Map.get(bundle, :accepted_core, [])},
      {:accepted_analog, Map.get(bundle, :accepted_analog, [])},
      {:background, Map.get(bundle, :background, [])}
    ]
    |> Enum.flat_map(fn {classification, records} ->
      Enum.map(records, fn %CanonicalRecord{} = record ->
        {record.id, {classification, record}}
      end)
    end)
    |> Map.new()
  end

  defp synthesis_formula_lookup(synthesis_run) do
    [
      Helpers.fetch(synthesis_run, :input_package, %{}) |> Helpers.fetch(:accepted_core, []),
      Helpers.fetch(synthesis_run, :input_package, %{}) |> Helpers.fetch(:accepted_analog, []),
      Helpers.fetch(synthesis_run, :input_package, %{}) |> Helpers.fetch(:background, [])
    ]
    |> List.flatten()
    |> Enum.reduce(%{}, fn record, acc ->
      case Helpers.fetch(record, :record_id) do
        value when is_binary(value) ->
          Map.put(acc, value, normalize_formula(Helpers.fetch(record, :formula, %{})))

        _ ->
          acc
      end
    end)
  end

  defp citation_lookup(snapshot_records, profile) do
    [
      :accepted_core,
      :accepted_analog,
      :background
    ]
    |> Enum.flat_map(fn classification ->
      snapshot_records
      |> Enum.flat_map(fn {_record_id, {record_classification, %CanonicalRecord{} = record}} ->
        if record_classification == classification, do: [{classification, record}], else: []
      end)
      |> Enum.sort_by(fn {_classification, record} ->
        {record.canonical_title || "", record.id}
      end)
    end)
    |> Enum.with_index(1)
    |> Map.new(fn {{_classification, %CanonicalRecord{id: record_id}}, ordinal} ->
      key =
        profile.citation_key_prefix <>
          String.pad_leading(Integer.to_string(ordinal), profile.citation_key_width, "0")

      {record_id, key}
    end)
  end

  defp invert_citation_lookup(citation_lookup) do
    Map.new(citation_lookup, fn {record_id, citation_key} -> {citation_key, record_id} end)
  end

  defp fetch_snapshot_record(snapshot_records, record_id) do
    case Map.fetch(snapshot_records, record_id) do
      {:ok, record} -> {:ok, record}
      :error -> {:error, {:missing_snapshot_record_for_citation, record_id}}
    end
  end

  defp fetch_snapshot_record_id(citation_key_lookup, citation_key) do
    case Map.fetch(citation_key_lookup, citation_key) do
      {:ok, record_id} -> {:ok, record_id}
      :error -> {:error, {:missing_snapshot_record_for_citation_key, citation_key}}
    end
  end

  defp normalize_scores(snapshot_record) do
    %{
      relevance: snapshot_record.relevance_score,
      evidence_strength: snapshot_record.evidence_strength_score,
      transferability: snapshot_record.transferability_score,
      citation_quality: snapshot_record.citation_quality_score,
      formula_actionability: snapshot_record.formula_actionability_score,
      external_validity_risk: snapshot_record.external_validity_risk,
      venue_specificity_flag: snapshot_record.venue_specificity_flag
    }
  end

  defp formula_payload(snapshot_record, formula_payload) do
    fallback_formula = %{
      status: snapshot_record.formula_completeness_status,
      exact_reusable_formula_texts: []
    }

    (formula_payload || fallback_formula)
    |> normalize_formula()
  end

  defp provenance_reference(
         %CanonicalRecord{source_provenance_summary: %SourceProvenanceSummary{} = summary} =
           record,
         synthesis_run
       ) do
    %{
      providers: Enum.sort(summary.providers),
      retrieval_run_ids: Enum.sort(summary.retrieval_run_ids),
      raw_record_ids: Enum.sort(summary.raw_record_ids),
      query_texts: Enum.sort(summary.query_texts),
      source_urls: Enum.sort(summary.source_urls),
      branch_kinds: Enum.sort(summary.branch_kinds),
      branch_labels: Enum.sort(summary.branch_labels),
      merged_from_canonical_ids: Enum.sort(summary.merged_from_canonical_ids),
      qa_reason_codes:
        record.qa_decisions
        |> Enum.flat_map(&Helpers.fetch(&1, :reason_codes, []))
        |> Enum.uniq()
        |> Enum.sort(),
      synthesis_run_id: Helpers.fetch(synthesis_run, :id)
    }
  end

  defp normalize_formula(formula) when is_map(formula) do
    %{
      status:
        Helpers.atomize(
          Helpers.fetch(formula, :status),
          [:exact, :partial, :referenced_only, :none, :unknown],
          :unknown
        ),
      exact_reusable_formula_texts:
        Helpers.fetch(formula, :exact_reusable_formula_texts, [])
        |> Helpers.normalize_string_list()
    }
  end

  defp normalize_formula(_formula), do: %{status: :unknown, exact_reusable_formula_texts: []}

  defp package(bundle, synthesis_run, artifact, report_sections, resolved_records, opts) do
    snapshot = bundle.snapshot

    section_lookup = Map.new(report_sections, &{&1.id, &1})

    package =
      %InputPackage{
        corpus_snapshot_id: snapshot.id,
        snapshot_label: snapshot.label,
        snapshot_finalized_at: snapshot.finalized_at,
        synthesis_run_id: Helpers.fetch(synthesis_run, :id),
        synthesis_artifact_id: Helpers.fetch(artifact, :id),
        synthesis_profile_id: Helpers.fetch(synthesis_run, :profile_id),
        artifact_hash: Helpers.fetch(artifact, :artifact_hash),
        artifact_finalized_at: Helpers.fetch(artifact, :finalized_at),
        normalized_theme_ids: snapshot.normalized_theme_ids || [],
        branch_ids: snapshot.branch_ids || [],
        report_sections: report_sections,
        section_lookup: section_lookup,
        resolved_records: resolved_records,
        cited_record_keys: Map.keys(resolved_records) |> Enum.sort(),
        snapshot_metadata: %{
          retrieval_run_ids: snapshot.retrieval_run_ids || [],
          qa_summary: Helpers.fetch(snapshot, :qa_summary, %{}),
          synthesis_cited_keys: Helpers.fetch(artifact, :cited_keys, [])
        },
        record_formula_availability:
          Map.new(resolved_records, fn {citation_key, record} ->
            {citation_key,
             %{
               status: Helpers.fetch(record.formula, :status),
               exact_reusable_formula_texts:
                 Helpers.fetch(record.formula, :exact_reusable_formula_texts, [])
             }}
          end),
        provenance_summaries:
          Map.new(resolved_records, fn {citation_key, record} ->
            {citation_key, record.provenance_reference}
          end),
        branch_context: Keyword.get(opts, :branch_context),
        theme_context: Keyword.get(opts, :theme_context),
        digest: "pending"
      }

    {:ok, %{package | digest: digest(package)}}
  end

  defp digest(package) do
    package
    |> Map.from_struct()
    |> Map.drop([:digest])
    |> Canonical.hash()
  end
end
