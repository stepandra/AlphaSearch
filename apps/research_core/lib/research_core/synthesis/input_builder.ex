defmodule ResearchCore.Synthesis.InputBuilder do
  @moduledoc """
  Deterministically packages a finalized snapshot for synthesis.
  """

  alias ResearchCore.Canonical
  alias ResearchCore.Corpus.{CanonicalRecord, QuarantineRecord, SourceProvenanceSummary}
  alias ResearchCore.Synthesis.{CitationKey, InputPackage, Profile}

  @excluded_inputs [
    "raw retrieval noise",
    "duplicate candidates that were rejected",
    "discarded records",
    "provider-specific hidden prompt state",
    "mutable or incomplete snapshots"
  ]

  @spec build(Profile.t(), map(), keyword()) :: {:ok, InputPackage.t()} | {:error, term()}
  def build(%Profile{} = profile, %{snapshot: snapshot} = bundle, opts \\ [])
      when is_map(snapshot) do
    include_background? =
      profile.include_background? and Keyword.get(opts, :include_background?, true)

    include_quarantine_summary? =
      profile.allow_quarantine_summary? and Keyword.get(opts, :include_quarantine_summary?, false)

    provenance_summaries = Keyword.get(opts, :provenance_summaries, %{})

    with :ok <- finalized_snapshot(snapshot) do
      included_records =
        [
          {:accepted_core, Map.get(bundle, :accepted_core, [])},
          {:accepted_analog, Map.get(bundle, :accepted_analog, [])},
          {:background, (include_background? && Map.get(bundle, :background, [])) || []}
        ]
        |> Enum.flat_map(fn {classification, records} ->
          records
          |> Enum.sort_by(&{&1.canonical_title || "", &1.id})
          |> Enum.map(&{classification, &1})
        end)

      citation_keys = build_citation_keys(included_records, profile)
      citation_lookup = Map.new(citation_keys, &{&1.record_id, &1})

      accepted_core =
        build_subset(
          Map.get(bundle, :accepted_core, []),
          :accepted_core,
          citation_lookup,
          provenance_summaries
        )

      accepted_analog =
        build_subset(
          Map.get(bundle, :accepted_analog, []),
          :accepted_analog,
          citation_lookup,
          provenance_summaries
        )

      background =
        if include_background? do
          build_subset(
            Map.get(bundle, :background, []),
            :background,
            citation_lookup,
            provenance_summaries
          )
        else
          []
        end

      quarantine_summary =
        if include_quarantine_summary? do
          build_quarantine_summary(Map.get(bundle, :quarantine, []))
        else
          []
        end

      package =
        %InputPackage{
          snapshot_id: snapshot.id,
          snapshot_label: snapshot.label,
          snapshot_finalized_at: snapshot.finalized_at,
          profile_id: profile.id,
          normalized_theme_ids: Enum.sort(snapshot.normalized_theme_ids || []),
          branch_ids: Enum.sort(snapshot.branch_ids || []),
          retrieval_run_ids: Enum.sort(snapshot.retrieval_run_ids || []),
          accepted_core: accepted_core,
          accepted_analog: accepted_analog,
          background: background,
          quarantine_summary: quarantine_summary,
          citation_keys: citation_keys,
          provenance_references:
            (accepted_core ++ accepted_analog ++ background)
            |> Map.new(fn record -> {record.record_id, record.provenance_reference} end),
          excluded_inputs: @excluded_inputs,
          digest: "pending"
        }

      {:ok, %{package | digest: digest(package)}}
    end
  end

  defp finalized_snapshot(%{finalized_at: %DateTime{}}), do: :ok
  defp finalized_snapshot(_snapshot), do: {:error, :snapshot_not_finalized}

  defp build_citation_keys(records, %Profile{} = profile) do
    records
    |> Enum.with_index(1)
    |> Enum.map(fn {{classification, %CanonicalRecord{id: record_id}}, ordinal} ->
      %CitationKey{
        key:
          profile.citation_key_prefix <>
            String.pad_leading(Integer.to_string(ordinal), profile.citation_key_width, "0"),
        record_id: record_id,
        classification: classification,
        ordinal: ordinal
      }
    end)
  end

  defp build_subset(records, classification, citation_lookup, provenance_summaries) do
    records
    |> Enum.sort_by(&{&1.canonical_title || "", &1.id})
    |> Enum.map(fn %CanonicalRecord{} = record ->
      citation = Map.fetch!(citation_lookup, record.id)
      provenance = Map.get(provenance_summaries, record.id, %{})

      %{
        record_id: record.id,
        classification: classification,
        citation_key: citation.key,
        title: record.canonical_title,
        citation: record.canonical_citation,
        url: record.canonical_url,
        year: record.year,
        authors: record.authors,
        source_type: record.source_type,
        abstract: record.abstract,
        methodology_summary: record.methodology_summary,
        findings_summary: record.findings_summary,
        limitations_summary: record.limitations_summary,
        direct_product_implication: record.direct_product_implication,
        formula: formula_payload(record, provenance),
        provenance_reference: provenance_reference(record.source_provenance_summary, provenance),
        scores: %{
          relevance: record.relevance_score,
          evidence_strength: record.evidence_strength_score,
          transferability: record.transferability_score,
          citation_quality: record.citation_quality_score,
          formula_actionability: record.formula_actionability_score,
          external_validity_risk: record.external_validity_risk,
          venue_specificity_flag: record.venue_specificity_flag
        }
      }
    end)
  end

  defp build_quarantine_summary(quarantine_records) do
    quarantine_records
    |> Enum.sort_by(& &1.id)
    |> Enum.map(fn %QuarantineRecord{} = quarantine_record ->
      %{
        id: quarantine_record.id,
        reason_codes: Enum.sort(quarantine_record.reason_codes),
        candidate_record_ids:
          quarantine_record.candidate_records
          |> Enum.reject(&is_nil/1)
          |> Enum.map(& &1.id)
          |> Enum.sort(),
        raw_record_ids: Enum.sort(quarantine_record.raw_record_ids)
      }
    end)
  end

  defp formula_payload(%CanonicalRecord{} = record, provenance) do
    exact_formulas = exact_formula_texts(provenance)

    %{
      status: record.formula_completeness_status,
      exact_reusable_formula_texts: exact_formulas,
      note: formula_note(record.formula_completeness_status, exact_formulas)
    }
  end

  defp formula_note(:exact, [_ | _]),
    do: "Exact reusable formula text is available from the snapshot provenance."

  defp formula_note(:exact, []),
    do: "Exact formula status is recorded, but no formula text was captured in provenance."

  defp formula_note(status, _formulas)
       when status in [:partial, :referenced_only] do
    "Formula is only partial or referenced; exact reusable text is unavailable."
  end

  defp formula_note(:none, _formulas), do: "No reusable formula is available for this record."
  defp formula_note(:unknown, _formulas), do: "Formula availability is unknown."

  defp provenance_reference(%SourceProvenanceSummary{} = summary, provenance) do
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
        provenance
        |> Map.get(:decisions, provenance["decisions"] || [])
        |> Enum.flat_map(&decision_reason_codes/1)
        |> Enum.uniq()
        |> Enum.sort()
    }
  end

  defp provenance_reference(_summary, provenance) do
    %{
      providers: [],
      retrieval_run_ids: [],
      raw_record_ids: [],
      query_texts: [],
      source_urls: [],
      branch_kinds: [],
      branch_labels: [],
      merged_from_canonical_ids: [],
      qa_reason_codes:
        provenance
        |> Map.get(:decisions, provenance["decisions"] || [])
        |> Enum.flat_map(&decision_reason_codes/1)
        |> Enum.uniq()
        |> Enum.sort()
    }
  end

  defp decision_reason_codes(%{reason_codes: reason_codes}), do: reason_codes
  defp decision_reason_codes(decision) when is_map(decision), do: decision["reason_codes"] || []
  defp decision_reason_codes(_decision), do: []

  defp exact_formula_texts(provenance) when is_map(provenance) do
    provenance
    |> Map.get(:raw_records, provenance["raw_records"] || [])
    |> Enum.map(fn raw_record ->
      Map.get(raw_record, :raw_fields, raw_record["raw_fields"] || %{})
    end)
    |> Enum.map(fn raw_fields -> raw_fields["formula_text"] || raw_fields[:formula_text] end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp digest(package) do
    Canonical.hash(package)
  end
end
