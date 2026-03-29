defmodule ResearchCore.Corpus.QA do
  @moduledoc """
  Deterministic corpus-quality gate for retrieval outputs.

  The pipeline operates in four inspectable stages:

  1. detect conflated raw records and split or quarantine them
  2. canonicalize raw records into a shared corpus shape
  3. group exact and near-duplicate canonical records
  4. classify canonical records into accepted, background, quarantine, or discard

  Every merge, split, discard, quarantine, and final classification decision is
  preserved in the returned `QAResult.decision_log`.
  """

  alias ResearchCore.Branch.{Branch, SearchQuery}

  alias ResearchCore.Corpus.{
    AcceptanceDecision,
    CanonicalRecord,
    DuplicateGroup,
    FormulaCompletenessStatus,
    QAResult,
    QuarantineRecord,
    RawRecord,
    SourceIdentifiers,
    SourceProvenanceSummary
  }

  @placeholder_titles MapSet.new([
                        "article",
                        "blog",
                        "document",
                        "home",
                        "homepage",
                        "landing page",
                        "link",
                        "paper",
                        "research",
                        "study",
                        "untitled",
                        "web page"
                      ])

  @stopwords MapSet.new([
               "a",
               "an",
               "and",
               "are",
               "as",
               "at",
               "by",
               "for",
               "from",
               "in",
               "into",
               "of",
               "on",
               "or",
               "the",
               "to",
               "via",
               "with"
             ])

  @source_type_map %{
    "conference paper" => :conference_paper,
    "journal article" => :journal_article,
    "official documentation" => :official_documentation,
    "official docs" => :official_documentation,
    "official site" => :official_site,
    "preprint" => :preprint,
    "report" => :report,
    "web page" => :web_page,
    "working paper" => :working_paper
  }

  @doc """
  Canonicalizes one raw corpus record into the shared record model.
  """
  @spec canonicalize(RawRecord.t()) :: CanonicalRecord.t()
  def canonicalize(%RawRecord{} = raw_record) do
    raw_title =
      raw_record
      |> raw_value(:title)
      |> fallback(raw_record.fetched_document && raw_record.fetched_document.title)
      |> fallback(raw_record.search_hit.title)

    content = raw_value(raw_record, :content) || fetched_content(raw_record)
    canonical_title = normalize_title(raw_title)
    canonical_url = normalize_url(raw_value(raw_record, :url) || raw_record.search_hit.url)

    identifiers =
      normalize_identifiers(
        raw_value(raw_record, :identifiers),
        raw_value(raw_record, :citation),
        canonical_url,
        content
      )

    authors = normalize_authors(raw_value(raw_record, :authors))

    year =
      normalize_year(raw_value(raw_record, :year) || raw_value(raw_record, :citation) || content)

    abstract =
      normalize_summary(
        raw_value(raw_record, :abstract) || extract_section(content, ["abstract"]) ||
          raw_record.search_hit.snippet
      )

    content_excerpt =
      normalize_summary(raw_value(raw_record, :content_excerpt) || excerpt(content))

    methodology_summary =
      normalize_summary(
        raw_value(raw_record, :methodology) ||
          extract_section(content, ["method", "methods", "methodology", "experimental setup"])
      )

    findings_summary =
      normalize_summary(
        raw_value(raw_record, :findings) ||
          extract_section(content, ["findings", "results", "conclusion", "conclusions"])
      )

    limitations_summary =
      normalize_summary(
        raw_value(raw_record, :limitations) ||
          extract_section(content, ["limitations", "discussion", "caveats"])
      )

    direct_product_implication =
      normalize_summary(
        raw_value(raw_record, :direct_product_implication) ||
          first_sentence_matching(content, ["implication", "application", "product", "trading"])
      )

    market_type =
      normalize_summary(
        raw_value(raw_record, :market_type) ||
          infer_market_type(raw_record, canonical_title, content)
      )

    source_type =
      infer_source_type(raw_value(raw_record, :source_type), identifiers, canonical_url)

    source_label = normalize_source_label(raw_value(raw_record, :source_label) || canonical_url)

    canonical_citation =
      raw_value(raw_record, :citation)
      |> normalize_citation()
      |> fallback(compose_citation(authors, year, canonical_title, identifiers, canonical_url))

    formula_completeness_status =
      normalize_formula_status(
        raw_value(raw_record, :formula_completeness_status),
        raw_value(raw_record, :formula_text),
        content
      )

    canonical_record =
      %CanonicalRecord{
        id: canonical_record_id(raw_record, canonical_title, identifiers, canonical_url, year),
        canonical_title: fallback(canonical_title, raw_record.search_hit.title) || "untitled",
        canonical_citation: canonical_citation,
        canonical_url: canonical_url,
        year: year,
        authors: authors,
        source_type: source_type,
        identifiers: identifiers,
        abstract: abstract,
        content_excerpt: content_excerpt,
        methodology_summary: methodology_summary,
        findings_summary: findings_summary,
        limitations_summary: limitations_summary,
        direct_product_implication: direct_product_implication,
        market_type: market_type,
        formula_completeness_status: formula_completeness_status,
        source_provenance_summary: build_source_provenance_summary(raw_record, canonical_url),
        raw_record_ids: [raw_record.id],
        normalized_fields: %{}
      }
      |> with_normalized_fields(source_label)

    enrich_record(canonical_record)
  end

  @doc """
  Groups exact and near-duplicate canonical records and returns the merged set.
  """
  @spec group_duplicates([CanonicalRecord.t()]) ::
          {[CanonicalRecord.t()], [DuplicateGroup.t()], [AcceptanceDecision.t()]}
  def group_duplicates(records) when is_list(records) do
    sorted_records = Enum.sort_by(records, & &1.id)
    pair_reasons = duplicate_pair_reasons(sorted_records)
    components = duplicate_components(sorted_records, pair_reasons)

    Enum.reduce(components, {[], [], []}, fn component,
                                             {records_acc, groups_acc, decisions_acc} ->
      case component do
        [record] ->
          {[record | records_acc], groups_acc, decisions_acc}

        group_records ->
          representative = choose_representative(group_records)

          merged_record =
            group_records
            |> Enum.reject(&(&1.id == representative.id))
            |> Enum.reduce(representative, &merge_canonical_record(&2, &1))
            |> enrich_record()

          group = build_duplicate_group(group_records, merged_record, pair_reasons)
          merge_decisions = build_merge_decisions(group_records, merged_record, group)

          {[merged_record | records_acc], [group | groups_acc], merge_decisions ++ decisions_acc}
      end
    end)
    |> then(fn {deduplicated, groups, decisions} ->
      {
        Enum.sort_by(deduplicated, & &1.id),
        Enum.sort_by(groups, & &1.id),
        sort_decisions(decisions)
      }
    end)
  end

  @doc """
  Runs the full corpus QA pipeline over raw retrieval material.
  """
  @spec process([RawRecord.t()]) :: QAResult.t()
  def process(raw_records) when is_list(raw_records) do
    {candidate_raw_records, preprocessing_quarantine, preprocessing_decisions} =
      raw_records
      |> Enum.sort_by(& &1.id)
      |> Enum.reduce({[], [], []}, fn raw_record, {candidate_acc, quarantine_acc, decision_acc} ->
        case preprocess_raw_record(raw_record) do
          {:candidate_records, records, decisions} ->
            {candidate_acc ++ records, quarantine_acc, decision_acc ++ decisions}

          {:quarantine, quarantine_record, decisions} ->
            {candidate_acc, quarantine_acc ++ [quarantine_record], decision_acc ++ decisions}
        end
      end)

    canonical_records = Enum.map(candidate_raw_records, &canonicalize/1)

    {deduplicated_records, duplicate_groups, duplicate_decisions} =
      group_duplicates(canonical_records)

    {accepted_core, accepted_analog, background, classification_quarantine, discard_log,
     classification_decisions} =
      classify_records(deduplicated_records)

    decision_log =
      (preprocessing_decisions ++ duplicate_decisions ++ classification_decisions)
      |> sort_decisions()

    accepted_core = attach_decisions(accepted_core, decision_log)
    accepted_analog = attach_decisions(accepted_analog, decision_log)
    background = attach_decisions(background, decision_log)

    quarantine =
      (preprocessing_quarantine ++ classification_quarantine)
      |> Enum.sort_by(& &1.id)

    %QAResult{
      accepted_core: accepted_core,
      accepted_analog: accepted_analog,
      background: background,
      quarantine: quarantine,
      discard_log: Enum.sort_by(discard_log, & &1.record_id),
      duplicate_groups: duplicate_groups,
      qa_decision_summary:
        decision_summary(
          accepted_core,
          accepted_analog,
          background,
          quarantine,
          discard_log,
          duplicate_groups,
          decision_log
        ),
      decision_log: decision_log
    }
  end

  defp preprocess_raw_record(%RawRecord{} = raw_record) do
    safe_title_parts =
      split_title_parts(raw_value(raw_record, :title) || raw_record.search_hit.title)

    safe_citation_parts = split_title_parts(raw_value(raw_record, :citation))

    cond do
      safe_split?(safe_title_parts, safe_citation_parts) ->
        split_records = build_split_records(raw_record, safe_title_parts, safe_citation_parts)

        decision = %AcceptanceDecision{
          record_id: raw_record.id,
          stage: :conflation_detection,
          action: :split,
          reason_codes: [:split_conflated_record],
          details: %{produced_record_ids: Enum.map(split_records, & &1.id)}
        }

        {:candidate_records, split_records, [decision]}

      unsafe_conflation?(raw_record) ->
        quarantine_record = build_conflation_quarantine(raw_record)
        {:quarantine, quarantine_record, [quarantine_record.decision]}

      true ->
        {:candidate_records, [raw_record], []}
    end
  end

  defp classify_records(records) do
    Enum.reduce(records, {[], [], [], [], [], []}, fn record,
                                                      {core_acc, analog_acc, background_acc,
                                                       quarantine_acc, discard_acc, decision_acc} ->
      case classify_record(record) do
        {:accepted_core, classified_record, decision} ->
          {[classified_record | core_acc], analog_acc, background_acc, quarantine_acc,
           discard_acc, [decision | decision_acc]}

        {:accepted_analog, classified_record, decision} ->
          {core_acc, [classified_record | analog_acc], background_acc, quarantine_acc,
           discard_acc, [decision | decision_acc]}

        {:background, classified_record, decision} ->
          {core_acc, analog_acc, [classified_record | background_acc], quarantine_acc,
           discard_acc, [decision | decision_acc]}

        {:quarantine, quarantine_record, decision} ->
          {core_acc, analog_acc, background_acc, [quarantine_record | quarantine_acc],
           discard_acc, [decision | decision_acc]}

        {:discard, decision} ->
          {core_acc, analog_acc, background_acc, quarantine_acc, [decision | discard_acc],
           [decision | decision_acc]}
      end
    end)
    |> then(fn {core, analog, background, quarantine, discard, decisions} ->
      {
        Enum.sort_by(core, & &1.id),
        Enum.sort_by(analog, & &1.id),
        Enum.sort_by(background, & &1.id),
        Enum.sort_by(quarantine, & &1.id),
        Enum.sort_by(discard, & &1.record_id),
        sort_decisions(decisions)
      }
    end)
  end

  defp classify_record(%CanonicalRecord{} = record) do
    case hard_fail(record) do
      {:discard, reasons} ->
        decision = classification_decision(record, :discarded, :discard, reasons)
        {:discard, decision}

      {:quarantine, reasons} ->
        decision = classification_decision(record, :quarantined, :quarantine, reasons)

        quarantine_record = %QuarantineRecord{
          id: quarantine_record_id(record.id),
          raw_record_ids: record.raw_record_ids,
          reason_codes: reasons,
          decision: decision,
          canonical_record: %CanonicalRecord{
            record
            | classification: :quarantine,
              qa_decisions: [decision]
          }
        }

        {:quarantine, quarantine_record, decision}

      nil ->
        cond do
          accepted_core?(record) ->
            decision =
              classification_decision(record, :accepted, :accepted_core, [:strong_core_evidence])

            {:accepted_core, %CanonicalRecord{record | classification: :accepted_core}, decision}

          accepted_analog?(record) ->
            decision =
              classification_decision(record, :accepted, :accepted_analog, [:analog_but_useful])

            {:accepted_analog, %CanonicalRecord{record | classification: :accepted_analog},
             decision}

          background_only?(record) ->
            decision =
              classification_decision(
                record,
                :downgraded,
                :background,
                background_reason_codes(record)
              )

            {:background, %CanonicalRecord{record | classification: :background}, decision}

          true ->
            decision =
              classification_decision(record, :discarded, :discard, [:thin_or_irrelevant_record])

            {:discard, decision}
        end
    end
  end

  defp hard_fail(%CanonicalRecord{} = record) do
    cond do
      url_only_pseudo_citation?(record) ->
        {:discard, [:url_only_pseudo_citation]}

      placeholder_title?(record.canonical_title) ->
        {:discard, [:placeholder_title]}

      is_nil(record.year) or record.year == 0 ->
        {:quarantine, [:missing_year]}

      critical_evidence_fields_missing?(record) and thin_content?(record) ->
        {:discard, [:incomplete_metadata, :thin_or_irrelevant_record]}

      critical_evidence_fields_missing?(record) ->
        {:quarantine, [:missing_critical_evidence_fields]}

      true ->
        nil
    end
  end

  defp accepted_core?(%CanonicalRecord{} = record) do
    core_signal?(record) and record.relevance_score >= 4 and record.evidence_strength_score >= 3 and
      record.citation_quality_score >= 3 and record.transferability_score >= 3 and
      record.external_validity_risk != :high
  end

  defp accepted_analog?(%CanonicalRecord{} = record) do
    not core_signal?(record) and analog_signal?(record) and record.relevance_score >= 2 and
      record.evidence_strength_score >= 2 and record.citation_quality_score >= 2
  end

  defp background_only?(%CanonicalRecord{} = record) do
    record.relevance_score >= 2 and record.citation_quality_score >= 2
  end

  defp background_reason_codes(%CanonicalRecord{} = record) do
    cond do
      record.evidence_strength_score <= 1 ->
        [:weak_theory_without_empirical_support]

      record.venue_specificity_flag or record.external_validity_risk == :high or
          record.transferability_score <= 2 ->
        [:venue_specific_limited_transferability]

      true ->
        [:background_only]
    end
  end

  defp classification_decision(%CanonicalRecord{} = record, action, classification, reason_codes) do
    %AcceptanceDecision{
      record_id: record.id,
      canonical_record_id: record.id,
      stage: :classification,
      action: action,
      classification: classification,
      reason_codes: reason_codes,
      score_snapshot: score_snapshot(record),
      details: %{
        source_type: record.source_type,
        formula_completeness_status: record.formula_completeness_status,
        venue_specificity_flag: record.venue_specificity_flag,
        external_validity_risk: record.external_validity_risk
      }
    }
  end

  defp build_conflation_quarantine(%RawRecord{} = raw_record) do
    decision = %AcceptanceDecision{
      record_id: raw_record.id,
      stage: :conflation_detection,
      action: :quarantined,
      classification: :quarantine,
      reason_codes: [:unsafe_conflation],
      details: %{title: raw_value(raw_record, :title) || raw_record.search_hit.title}
    }

    %QuarantineRecord{
      id: quarantine_record_id(raw_record.id),
      raw_record_ids: [raw_record.id],
      reason_codes: [:unsafe_conflation],
      decision: decision,
      details: %{search_url: raw_record.search_hit.url}
    }
  end

  defp build_split_records(%RawRecord{} = raw_record, title_parts, citation_parts) do
    Enum.with_index(title_parts, 1)
    |> Enum.map(fn {title_part, index} ->
      citation_part = Enum.at(citation_parts, index - 1)

      %RawRecord{
        raw_record
        | id: raw_record.id <> ":split:" <> Integer.to_string(index),
          split_from_id: raw_record.id,
          fetched_document: nil,
          search_hit: %{raw_record.search_hit | title: title_part},
          raw_fields:
            raw_record.raw_fields
            |> Map.put(:title, title_part)
            |> maybe_put(:citation, citation_part)
      }
    end)
  end

  defp duplicate_pair_reasons(records) do
    for {left, left_index} <- Enum.with_index(records),
        {right, right_index} <- Enum.with_index(records),
        right_index > left_index,
        reasons = duplicate_reasons(left, right),
        reasons != [],
        into: %{} do
      {pair_key(left.id, right.id), reasons}
    end
  end

  defp duplicate_components(records, pair_reasons) do
    adjacency =
      pair_reasons
      |> Map.keys()
      |> Enum.reduce(%{}, fn {left_id, right_id}, acc ->
        acc
        |> Map.update(left_id, [right_id], &[right_id | &1])
        |> Map.update(right_id, [left_id], &[left_id | &1])
      end)

    record_map = Map.new(records, &{&1.id, &1})

    Enum.reduce(Enum.map(records, & &1.id), {[], MapSet.new()}, fn record_id,
                                                                   {components, seen} ->
      if MapSet.member?(seen, record_id) do
        {components, seen}
      else
        {component_ids, seen} = traverse_component(record_id, adjacency, seen, [])

        component_records =
          component_ids
          |> Enum.uniq()
          |> Enum.sort()
          |> Enum.map(&Map.fetch!(record_map, &1))

        {[component_records | components], seen}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp traverse_component(record_id, adjacency, seen, stack) do
    if MapSet.member?(seen, record_id) do
      {stack, seen}
    else
      neighbors = Map.get(adjacency, record_id, [])
      seen = MapSet.put(seen, record_id)

      Enum.reduce(neighbors, {[record_id | stack], seen}, fn neighbor_id,
                                                             {component_ids, acc_seen} ->
        traverse_component(neighbor_id, adjacency, acc_seen, component_ids)
      end)
    end
  end

  defp duplicate_reasons(left, right) do
    identifier_reasons(left.identifiers, right.identifiers) ++
      exact_title_reasons(left, right) ++
      exact_url_reasons(left, right) ++ near_title_reasons(left, right)
  end

  defp identifier_reasons(%SourceIdentifiers{} = left, %SourceIdentifiers{} = right) do
    [:doi, :arxiv, :ssrn, :nber, :osf]
    |> Enum.reduce([], fn identifier_key, reasons ->
      left_value = Map.get(left, identifier_key)
      right_value = Map.get(right, identifier_key)

      if present?(left_value) and left_value == right_value do
        reasons ++ [%{rule: :exact_identifier, identifier: identifier_key, value: left_value}]
      else
        reasons
      end
    end)
  end

  defp exact_title_reasons(left, right) do
    left_title = normalized_title_key(left.canonical_title)
    right_title = normalized_title_key(right.canonical_title)

    if present?(left_title) and left_title == right_title do
      [%{rule: :exact_normalized_title, value: left_title}]
    else
      []
    end
  end

  defp exact_url_reasons(left, right) do
    if present?(left.canonical_url) and left.canonical_url == right.canonical_url and
         not shared_split_origin?(left, right) do
      [%{rule: :exact_canonical_url, value: left.canonical_url}]
    else
      []
    end
  end

  defp near_title_reasons(left, right) do
    if normalized_title_key(left.canonical_title) == normalized_title_key(right.canonical_title) do
      []
    else
      left_tokens = significant_tokens(left.canonical_title)
      right_tokens = significant_tokens(right.canonical_title)
      overlap = MapSet.intersection(left_tokens, right_tokens)
      overlap_count = MapSet.size(overlap)
      denominator = max(MapSet.size(left_tokens), MapSet.size(right_tokens))
      overlap_ratio = if denominator == 0, do: 0.0, else: overlap_count / denominator
      year_relation = year_relation(left.year, right.year)

      if overlap_count >= 4 and overlap_ratio >= 0.8 and year_relation in [:same, :compatible] do
        [
          %{
            rule: :near_duplicate_title,
            shared_tokens: overlap |> MapSet.to_list() |> Enum.sort(),
            overlap_ratio: Float.round(overlap_ratio, 2),
            year_relation: year_relation
          }
        ]
      else
        []
      end
    end
  end

  defp choose_representative(records) do
    records
    |> Enum.sort_by(fn record -> {record.id, representative_rank(record)} end)
    |> Enum.sort_by(&representative_rank/1, :desc)
    |> hd()
  end

  defp representative_rank(%CanonicalRecord{} = record) do
    {
      SourceIdentifiers.count(record.identifiers),
      record.citation_quality_score,
      record.evidence_strength_score,
      filled_field_count(record),
      text_length(record.content_excerpt),
      text_length(record.canonical_title)
    }
  end

  defp merge_canonical_record(%CanonicalRecord{} = kept, %CanonicalRecord{} = duplicate) do
    merged_identifiers = merge_identifiers(kept.identifiers, duplicate.identifiers)

    merged_provenance =
      merge_provenance(
        kept.source_provenance_summary,
        duplicate.source_provenance_summary,
        duplicate.id
      )

    %CanonicalRecord{
      kept
      | canonical_title: preferred_text(kept.canonical_title, duplicate.canonical_title),
        canonical_citation: preferred_text(kept.canonical_citation, duplicate.canonical_citation),
        canonical_url: preferred_text(kept.canonical_url, duplicate.canonical_url),
        year: preferred_year(kept.year, duplicate.year),
        authors: preferred_list(kept.authors, duplicate.authors),
        source_type: preferred_source_type(kept.source_type, duplicate.source_type),
        identifiers: merged_identifiers,
        abstract: preferred_text(kept.abstract, duplicate.abstract),
        content_excerpt: preferred_text(kept.content_excerpt, duplicate.content_excerpt),
        methodology_summary:
          preferred_text(kept.methodology_summary, duplicate.methodology_summary),
        findings_summary: preferred_text(kept.findings_summary, duplicate.findings_summary),
        limitations_summary:
          preferred_text(kept.limitations_summary, duplicate.limitations_summary),
        direct_product_implication:
          preferred_text(kept.direct_product_implication, duplicate.direct_product_implication),
        market_type: preferred_text(kept.market_type, duplicate.market_type),
        formula_completeness_status:
          preferred_formula_status(
            kept.formula_completeness_status,
            duplicate.formula_completeness_status
          ),
        source_provenance_summary: merged_provenance,
        raw_record_ids:
          (kept.raw_record_ids ++ duplicate.raw_record_ids) |> Enum.uniq() |> Enum.sort(),
        normalized_fields: %{}
    }
    |> with_normalized_fields(
      normalize_source_label(kept.canonical_url || duplicate.canonical_url)
    )
    |> then(fn %CanonicalRecord{} = merged_record ->
      %{
        merged_record
        | normalized_fields:
            Map.put(
              merged_record.normalized_fields,
              :merged_from_record_ids,
              merged_provenance.merged_from_canonical_ids
            )
      }
    end)
  end

  defp merge_identifiers(%SourceIdentifiers{} = left, %SourceIdentifiers{} = right) do
    %SourceIdentifiers{
      doi: preferred_text(left.doi, right.doi),
      arxiv: preferred_text(left.arxiv, right.arxiv),
      ssrn: preferred_text(left.ssrn, right.ssrn),
      nber: preferred_text(left.nber, right.nber),
      osf: preferred_text(left.osf, right.osf),
      url: preferred_text(left.url, right.url)
    }
  end

  defp merge_provenance(
         %SourceProvenanceSummary{} = left,
         %SourceProvenanceSummary{} = right,
         merged_record_id
       ) do
    %SourceProvenanceSummary{
      providers: sort_atoms(left.providers ++ right.providers),
      retrieval_run_ids: uniq_sort(left.retrieval_run_ids ++ right.retrieval_run_ids),
      raw_record_ids: uniq_sort(left.raw_record_ids ++ right.raw_record_ids),
      query_texts: uniq_sort(left.query_texts ++ right.query_texts),
      source_urls: uniq_sort(left.source_urls ++ right.source_urls),
      branch_kinds: sort_atoms(left.branch_kinds ++ right.branch_kinds),
      branch_labels: uniq_sort(left.branch_labels ++ right.branch_labels),
      merged_from_canonical_ids:
        uniq_sort(
          left.merged_from_canonical_ids ++ right.merged_from_canonical_ids ++ [merged_record_id]
        )
    }
  end

  defp build_duplicate_group(group_records, merged_record, pair_reasons) do
    group_id = stable_id("duplicate-group", Enum.map(group_records, & &1.id))
    decisions = build_merge_decisions(group_records, merged_record, group_id)

    %DuplicateGroup{
      id: group_id,
      canonical_record_id: merged_record.id,
      representative_record_id: merged_record.id,
      member_record_ids: Enum.map(group_records, & &1.id),
      member_raw_record_ids:
        group_records |> Enum.flat_map(& &1.raw_record_ids) |> Enum.uniq() |> Enum.sort(),
      match_reasons: duplicate_group_reasons(group_records, pair_reasons),
      decisions: decisions
    }
  end

  defp build_merge_decisions(group_records, merged_record, %DuplicateGroup{id: group_id}) do
    build_merge_decisions(group_records, merged_record, group_id)
  end

  defp build_merge_decisions(group_records, merged_record, group_id) do
    group_records
    |> Enum.reject(&(&1.id == merged_record.id))
    |> Enum.map(fn duplicate_record ->
      %AcceptanceDecision{
        record_id: duplicate_record.id,
        canonical_record_id: merged_record.id,
        stage: :duplicate_grouping,
        action: :merged,
        reason_codes: [:duplicate_merged],
        duplicate_group_id: group_id,
        details: %{raw_record_ids: duplicate_record.raw_record_ids}
      }
    end)
  end

  defp duplicate_group_reasons(group_records, pair_reasons) do
    group_ids = Enum.map(group_records, & &1.id) |> MapSet.new()

    pair_reasons
    |> Enum.filter(fn {{left_id, right_id}, _reasons} ->
      MapSet.member?(group_ids, left_id) and MapSet.member?(group_ids, right_id)
    end)
    |> Enum.flat_map(fn {_pair, reasons} -> reasons end)
    |> Enum.uniq()
    |> Enum.sort_by(&{&1.rule, inspect(&1)})
  end

  defp attach_decisions(records, decision_log) do
    Enum.map(records, fn %CanonicalRecord{} = record ->
      related_decisions =
        decision_log
        |> Enum.filter(fn decision ->
          decision.canonical_record_id == record.id or decision.record_id == record.id
        end)
        |> sort_decisions()

      %CanonicalRecord{record | qa_decisions: related_decisions}
    end)
  end

  defp build_source_provenance_summary(%RawRecord{} = raw_record, canonical_url) do
    query = raw_record.search_hit.query

    branch_kind =
      cond do
        match?(%Branch{}, raw_record.branch) -> raw_record.branch.kind
        match?(%SearchQuery{}, query) -> query.branch_kind
        true -> nil
      end

    branch_label =
      cond do
        match?(%Branch{}, raw_record.branch) -> raw_record.branch.label
        match?(%SearchQuery{}, query) -> query.branch_label
        true -> nil
      end

    %SourceProvenanceSummary{
      providers: [raw_record.search_hit.provider],
      retrieval_run_ids: reject_blank([raw_record.retrieval_run_id]),
      raw_record_ids: [raw_record.id],
      query_texts: reject_blank([query && query.text]),
      source_urls: reject_blank([canonical_url]),
      branch_kinds: reject_nil([branch_kind]),
      branch_labels: reject_blank([branch_label]),
      merged_from_canonical_ids: []
    }
  end

  defp enrich_record(%CanonicalRecord{} = record) do
    venue_specificity_flag = venue_specific?(record)
    external_validity_risk = external_validity_risk(record, venue_specificity_flag)

    %CanonicalRecord{
      record
      | citation_quality_score: citation_quality_score(record),
        relevance_score: relevance_score(record),
        evidence_strength_score: evidence_strength_score(record),
        transferability_score:
          transferability_score(record, venue_specificity_flag, external_validity_risk),
        formula_actionability_score:
          formula_actionability_score(record.formula_completeness_status),
        venue_specificity_flag: venue_specificity_flag,
        external_validity_risk: external_validity_risk
    }
  end

  defp citation_quality_score(%CanonicalRecord{} = record) do
    score =
      0
      |> maybe_increment(bibliographic_identifier_count(record.identifiers) > 0, 2)
      |> maybe_increment(not is_nil(record.year), 1)
      |> maybe_increment(record.authors != [], 1)
      |> maybe_increment(not placeholder_title?(record.canonical_title), 1)
      |> maybe_increment(present?(record.canonical_url), 1)

    min(score, 5)
  end

  defp relevance_score(%CanonicalRecord{} = record) do
    target_tokens =
      (record.source_provenance_summary.query_texts ++
         record.source_provenance_summary.branch_labels)
      |> Enum.join(" ")
      |> significant_tokens()

    target_tokens =
      if MapSet.size(target_tokens) == 0 do
        significant_tokens(record.canonical_title)
      else
        target_tokens
      end

    content_tokens =
      [
        record.canonical_title,
        record.abstract,
        record.methodology_summary,
        record.findings_summary,
        record.market_type
      ]
      |> Enum.join(" ")
      |> significant_tokens()

    overlap = MapSet.intersection(target_tokens, content_tokens) |> MapSet.size()

    cond do
      overlap >= 5 -> 5
      overlap >= 3 -> 4
      overlap >= 2 -> 3
      overlap >= 1 -> 2
      analog_signal?(record) and present?(record.market_type) -> 2
      true -> 1
    end
  end

  defp evidence_strength_score(%CanonicalRecord{} = record) do
    filled_fields =
      [
        record.abstract,
        record.methodology_summary,
        record.findings_summary,
        record.limitations_summary
      ]
      |> Enum.count(&present?/1)

    empirical_bonus =
      if contains_any?(combined_record_text(record), [
           "experiment",
           "empirical",
           "dataset",
           "sample",
           "survey",
           "participants",
           "regression"
         ]) do
        1
      else
        0
      end

    source_bonus =
      if record.source_type in [:conference_paper, :journal_article, :preprint, :working_paper] do
        1
      else
        0
      end

    min(filled_fields + empirical_bonus + source_bonus, 5)
  end

  defp transferability_score(
         %CanonicalRecord{} = record,
         venue_specificity_flag,
         external_validity_risk
       ) do
    base = if analog_signal?(record), do: 3, else: 4

    base =
      if record.source_type in [:official_documentation, :official_site], do: base - 2, else: base

    base = if venue_specificity_flag, do: base - 1, else: base

    base =
      case external_validity_risk do
        :high -> min(base, 2)
        :medium -> min(base, 3)
        _ -> base
      end

    clamp_score(base)
  end

  defp formula_actionability_score(:exact), do: 5
  defp formula_actionability_score(:partial), do: 4
  defp formula_actionability_score(:referenced_only), do: 2
  defp formula_actionability_score(:unknown), do: 1
  defp formula_actionability_score(:none), do: 0

  defp venue_specific?(%CanonicalRecord{} = record) do
    record.source_type in [:official_documentation, :official_site] or
      contains_any?(combined_record_text(record), [
        "case study",
        "exchange-specific",
        "platform-specific",
        "single venue"
      ]) or
      Enum.any?(record.source_provenance_summary.query_texts, fn query_text ->
        contains_any?(query_text, ["site:", "exchange docs", "api docs"])
      end)
  end

  defp external_validity_risk(%CanonicalRecord{} = record, venue_specificity_flag) do
    cond do
      venue_specificity_flag -> :high
      analog_signal?(record) -> :medium
      record.source_type in [:web_page, :report, :working_paper, :preprint] -> :medium
      true -> :low
    end
  end

  defp core_signal?(%CanonicalRecord{} = record) do
    record.source_provenance_summary.branch_kinds
    |> Enum.any?(&(&1 in [:direct, :narrower, :broader, :mechanism, :method]))
  end

  defp analog_signal?(%CanonicalRecord{} = record) do
    record.source_provenance_summary.branch_kinds != [] and
      Enum.all?(record.source_provenance_summary.branch_kinds, &(&1 == :analog))
  end

  defp url_only_pseudo_citation?(%CanonicalRecord{} = record) do
    only_url_identifier? =
      record.identifiers
      |> Map.from_struct()
      |> Enum.all?(fn {key, value} -> key == :url or not present?(value) end)

    url_citation? =
      record.canonical_citation
      |> normalize_citation()
      |> then(&(present?(&1) and url_string?(&1)))

    only_url_identifier? and url_citation? and record.authors == [] and is_nil(record.year) and
      placeholder_title?(record.canonical_title)
  end

  defp critical_evidence_fields_missing?(%CanonicalRecord{} = record) do
    Enum.all?(
      [record.methodology_summary, record.findings_summary, record.limitations_summary],
      &(not present?(&1))
    )
  end

  defp thin_content?(%CanonicalRecord{} = record) do
    text_length(record.abstract) < 80 and text_length(record.content_excerpt) < 80
  end

  defp unsafe_conflation?(%RawRecord{} = raw_record) do
    title = raw_value(raw_record, :title) || raw_record.search_hit.title
    citation = raw_value(raw_record, :citation)
    content = fetched_content(raw_record)

    identifier_count =
      raw_record
      |> raw_value(:identifiers)
      |> normalize_identifiers(citation, raw_record.search_hit.url, content)
      |> bibliographic_identifier_count()

    explicit_multi_record_signal? =
      explicit_multi_record_signal?(title) or explicit_multi_record_signal?(citation) or
        explicit_multi_record_signal?(content)

    separator_signal? =
      strong_separator?(citation) or (strong_separator?(title) and strong_separator?(citation))

    identifier_signal? =
      identifier_count > 1 and (separator_signal? or explicit_multi_record_signal?)

    multiple_years?(title) or multiple_years?(citation) or explicit_multi_record_signal? or
      identifier_signal?
  end

  defp safe_split?(title_parts, citation_parts) do
    length(title_parts) >= 2 and length(title_parts) <= 3 and
      Enum.all?(title_parts, &split_candidate_title?/1) and
      citation_parts != [] and length(citation_parts) == length(title_parts) and
      Enum.all?(citation_parts, &split_candidate_citation?/1)
  end

  defp split_title_parts(nil), do: []

  defp split_title_parts(text) when is_binary(text) do
    text
    |> String.split(~r/\s*(?:;|\|)\s*/, trim: true)
    |> Enum.map(&normalize_summary/1)
    |> reject_blank()
  end

  defp split_candidate_title?(title_part) do
    MapSet.size(significant_tokens(title_part)) >= 3 and not placeholder_title?(title_part)
  end

  defp split_candidate_citation?(citation_part) do
    normalize_year(citation_part) != nil and contains_any?(citation_part, ["(", ")", ","])
  end

  defp strong_separator?(text) when is_binary(text) do
    Regex.match?(~r/\s(?:;|\|)\s/, text)
  end

  defp strong_separator?(_text), do: false

  defp multiple_years?(text) when is_binary(text) do
    Regex.scan(~r/(?:19|20)\d{2}/, text)
    |> length()
    |> Kernel.>(1)
  end

  defp multiple_years?(_text), do: false

  defp explicit_multi_record_signal?(text) when is_binary(text) do
    contains_any?(text, [
      "multiple papers",
      "mixed citations",
      "merged citation",
      "blends multiple papers",
      "one source blob",
      "two papers",
      "three papers"
    ])
  end

  defp explicit_multi_record_signal?(_text), do: false

  defp normalize_identifiers(raw_identifiers, citation, canonical_url, content) do
    identifier_map = normalize_identifier_input(raw_identifiers)
    identifier_source = Enum.join(reject_blank([citation, content, canonical_url]), " ")

    %SourceIdentifiers{
      doi: normalize_doi(identifier_map[:doi] || extract_doi(identifier_source)),
      arxiv: normalize_arxiv(identifier_map[:arxiv] || extract_arxiv(identifier_source)),
      ssrn: normalize_ssrn(identifier_map[:ssrn] || extract_ssrn(identifier_source)),
      nber: normalize_nber(identifier_map[:nber] || extract_nber(identifier_source)),
      osf: normalize_osf(identifier_map[:osf] || extract_osf(identifier_source)),
      url: normalize_url(identifier_map[:url] || canonical_url)
    }
  end

  defp normalize_identifier_input(%SourceIdentifiers{} = identifiers),
    do: Map.from_struct(identifiers)

  defp normalize_identifier_input(nil), do: %{}

  defp normalize_identifier_input(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      normalized_key =
        case key do
          key when is_atom(key) ->
            key

          key when is_binary(key) ->
            case String.downcase(String.trim(key)) do
              "doi" -> :doi
              "arxiv" -> :arxiv
              "ssrn" -> :ssrn
              "nber" -> :nber
              "osf" -> :osf
              "url" -> :url
              _ -> nil
            end

          _ ->
            nil
        end

      if normalized_key do
        Map.put(acc, normalized_key, value)
      else
        acc
      end
    end)
  end

  defp normalize_identifier_input(value) when is_binary(value) do
    cond do
      url_string?(value) -> %{url: value}
      Regex.match?(~r/10\.\d{4,9}\//i, value) -> %{doi: value}
      Regex.match?(~r/arxiv/i, value) -> %{arxiv: value}
      true -> %{}
    end
  end

  defp normalize_title(nil), do: nil

  defp normalize_title(title) when is_binary(title) do
    title
    |> String.trim_leading()
    |> String.replace(~r/^\[[^\]]+\]\s*/u, "")
    |> normalize_summary()
  end

  defp normalize_citation(nil), do: nil

  defp normalize_citation(citation) when is_binary(citation) do
    citation
    |> normalize_summary()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_url(nil), do: nil

  defp normalize_url(url) when is_binary(url) do
    trimmed = String.trim(url)

    case URI.parse(trimmed) do
      %URI{scheme: scheme, host: host} = uri when is_binary(scheme) and is_binary(host) ->
        cleaned_query =
          uri.query
          |> decode_query()
          |> Enum.reject(fn {key, _value} -> String.starts_with?(key, "utm_") end)
          |> Enum.sort()
          |> Enum.into(%{})
          |> case do
            map when map == %{} -> nil
            map -> URI.encode_query(map)
          end

        path =
          uri.path
          |> fallback("/")
          |> String.replace_trailing("/", "")
          |> fallback("/")

        %URI{
          uri
          | scheme: String.downcase(scheme),
            host: String.downcase(host),
            path: path,
            query: cleaned_query,
            fragment: nil
        }
        |> URI.to_string()

      _ ->
        nil
    end
  end

  defp normalize_authors(nil), do: []

  defp normalize_authors(authors) when is_list(authors) do
    authors
    |> Enum.map(&normalize_summary/1)
    |> reject_blank()
  end

  defp normalize_authors(authors) when is_binary(authors) do
    authors
    |> String.split(~r/\s*(?:;|\band\b|&)\s*/i, trim: true)
    |> Enum.map(&normalize_summary/1)
    |> reject_blank()
  end

  defp normalize_year(nil), do: nil
  defp normalize_year(0), do: nil

  defp normalize_year(year) when is_integer(year) do
    current_year = Date.utc_today().year + 1

    if year in 1900..current_year, do: year, else: nil
  end

  defp normalize_year(value) when is_binary(value) do
    current_year = Date.utc_today().year + 1

    Regex.scan(~r/(?:19|20)\d{2}/, value)
    |> List.flatten()
    |> Enum.map(&String.to_integer/1)
    |> Enum.find(&(&1 in 1900..current_year))
  end

  defp normalize_summary(nil), do: nil

  defp normalize_summary(text) when is_binary(text) do
    text
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.trim_trailing(".")
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_source_label(nil), do: nil

  defp normalize_source_label(source_label) when is_binary(source_label) do
    cond do
      url_string?(source_label) ->
        source_label
        |> normalize_url()
        |> hostname()

      true ->
        source_label
        |> normalize_summary()
        |> then(&if(&1, do: String.downcase(&1), else: nil))
    end
  end

  defp normalize_formula_status(status, formula_text, content) do
    cond do
      FormulaCompletenessStatus.valid?(status) ->
        status

      is_binary(status) ->
        case String.downcase(String.trim(status)) do
          "exact" -> :exact
          "partial" -> :partial
          "referenced_only" -> :referenced_only
          "none" -> :none
          "unknown" -> :unknown
          _ -> infer_formula_status(formula_text || content)
        end

      true ->
        infer_formula_status(formula_text || content)
    end
  end

  defp infer_formula_status(nil), do: :unknown

  defp infer_formula_status(text) do
    cond do
      Regex.match?(
        ~r/(\$[^$]+\$|\\\([^\)]+\\\)|\\\[[^\]]+\\\]|\b[a-z][a-z0-9_]*\s*=\s*[^\n]+)/iu,
        text
      ) ->
        :exact

      contains_any?(text, ["equation", "formula", "model"]) and Regex.match?(~r/[=<>]/, text) ->
        :partial

      contains_any?(text, ["equation", "formula", "model"]) ->
        :referenced_only

      String.trim(text) == "" ->
        :unknown

      true ->
        :none
    end
  end

  defp infer_source_type(nil, identifiers, canonical_url),
    do: infer_source_type_from_identifiers(identifiers, canonical_url)

  defp infer_source_type(value, _identifiers, _canonical_url)
       when value in [
              :conference_paper,
              :journal_article,
              :official_documentation,
              :official_site,
              :preprint,
              :report,
              :web_page,
              :working_paper
            ],
       do: value

  defp infer_source_type(value, identifiers, canonical_url) when is_atom(value) do
    infer_source_type(Atom.to_string(value), identifiers, canonical_url)
  end

  defp infer_source_type(value, identifiers, canonical_url) when is_binary(value) do
    case Map.get(@source_type_map, String.downcase(String.trim(value))) do
      nil -> infer_source_type_from_identifiers(identifiers, canonical_url)
      mapped -> mapped
    end
  end

  defp infer_source_type_from_identifiers(%SourceIdentifiers{doi: doi}, _canonical_url)
       when is_binary(doi), do: :journal_article

  defp infer_source_type_from_identifiers(%SourceIdentifiers{arxiv: arxiv}, _canonical_url)
       when is_binary(arxiv), do: :preprint

  defp infer_source_type_from_identifiers(%SourceIdentifiers{ssrn: ssrn}, _canonical_url)
       when is_binary(ssrn), do: :working_paper

  defp infer_source_type_from_identifiers(%SourceIdentifiers{nber: nber}, _canonical_url)
       when is_binary(nber), do: :working_paper

  defp infer_source_type_from_identifiers(%SourceIdentifiers{osf: osf}, _canonical_url)
       when is_binary(osf), do: :report

  defp infer_source_type_from_identifiers(_identifiers, canonical_url) do
    infer_source_type_from_url(canonical_url)
  end

  defp infer_source_type_from_url(canonical_url) do
    host = hostname(canonical_url)

    cond do
      host in ["docs.rs", "readthedocs.io"] -> :official_documentation
      present?(host) and String.contains?(host, "docs") -> :official_documentation
      present?(host) -> :web_page
      true -> :unknown
    end
  end

  defp infer_market_type(raw_record, canonical_title, content) do
    text =
      [
        canonical_title,
        content,
        raw_record.search_hit.query && raw_record.search_hit.query.branch_label
      ]
      |> Enum.join(" ")
      |> String.downcase()

    cond do
      String.contains?(text, "prediction market") -> "prediction market"
      String.contains?(text, "order book") -> "order book"
      String.contains?(text, "options") -> "options market"
      String.contains?(text, "sportsbook") -> "sportsbook"
      analog_branch?(raw_record) -> "analog"
      true -> nil
    end
  end

  defp analog_branch?(%RawRecord{branch: %Branch{kind: :analog}}), do: true

  defp analog_branch?(%RawRecord{search_hit: %{query: %SearchQuery{branch_kind: :analog}}}),
    do: true

  defp analog_branch?(_raw_record), do: false

  defp compose_citation(authors, year, title, identifiers, canonical_url) do
    cond do
      (authors != [] and year) && present?(title) ->
        Enum.join(authors, ", ") <> " (" <> Integer.to_string(year) <> "). " <> title

      present?(title) and year ->
        title <> " (" <> Integer.to_string(year) <> ")"

      not SourceIdentifiers.blank?(identifiers) ->
        primary_identifier(identifiers)

      present?(canonical_url) ->
        canonical_url

      true ->
        nil
    end
  end

  defp canonical_record_id(raw_record, canonical_title, identifiers, canonical_url, year) do
    stable_id(
      "canonical-record",
      [
        raw_record.id,
        primary_identifier(identifiers),
        canonical_url,
        canonical_title,
        year && Integer.to_string(year)
      ]
    )
  end

  defp primary_identifier(%SourceIdentifiers{} = identifiers) do
    identifiers.doi || identifiers.arxiv || identifiers.ssrn || identifiers.nber ||
      identifiers.osf || identifiers.url
  end

  defp extract_section(nil, _headings), do: nil

  defp extract_section(text, headings) do
    heading_pattern = Enum.join(headings, "|")

    regex =
      Regex.compile!(
        "(?:^|\\n)(?:#+\\s*)?(?:#{heading_pattern})\\s*:?\\s*\\n+(.+?)(?=\\n(?:#+\\s*[A-Z][^\\n]*|[A-Z][^\\n]*:\\s*$)|\\z)",
        [:caseless, :dotall, :unicode]
      )

    case Regex.run(regex, text) do
      [_, section] -> excerpt(section)
      _ -> nil
    end
  end

  defp first_sentence_matching(nil, _keywords), do: nil

  defp first_sentence_matching(text, keywords) do
    text
    |> String.split(~r/(?<=[.!?])\s+/u, trim: true)
    |> Enum.find(&contains_any?(&1, keywords))
    |> normalize_summary()
  end

  defp excerpt(nil), do: nil

  defp excerpt(text) do
    text
    |> normalize_summary()
    |> case do
      nil ->
        nil

      normalized ->
        if String.length(normalized) <= 240 do
          normalized
        else
          String.slice(normalized, 0, 237) <> "..."
        end
    end
  end

  defp fetched_content(%RawRecord{fetched_document: %{content: content}}), do: content
  defp fetched_content(_raw_record), do: nil

  defp raw_value(%RawRecord{raw_fields: raw_fields}, key) do
    Map.get(raw_fields, key) || Map.get(raw_fields, Atom.to_string(key))
  end

  defp extract_doi(nil), do: nil

  defp extract_doi(text) do
    case Regex.run(~r/\b10\.\d{4,9}\/[\w.()\-;:\/]+/i, text) do
      [doi] -> doi
      _ -> nil
    end
  end

  defp normalize_doi(nil), do: nil

  defp normalize_doi(doi) when is_binary(doi) do
    doi
    |> String.trim()
    |> String.replace_prefix("https://doi.org/", "")
    |> String.replace_prefix("http://doi.org/", "")
    |> String.replace_prefix("doi:", "")
    |> String.trim_trailing(".")
    |> String.trim_trailing(",")
    |> String.trim_trailing(";")
    |> String.downcase()
  end

  defp extract_arxiv(nil), do: nil

  defp extract_arxiv(text) do
    case Regex.run(
           ~r/(?:arxiv(?:\.org\/(?:abs|pdf)\/)?:?\s*)([a-z\-.]+\/\d{7}|\d{4}\.\d{4,5})(?:v\d+)?/i,
           text
         ) do
      [_, arxiv_id] -> arxiv_id
      _ -> nil
    end
  end

  defp normalize_arxiv(nil), do: nil

  defp normalize_arxiv(arxiv),
    do: arxiv |> String.trim() |> String.downcase() |> String.replace(~r/v\d+$/i, "")

  defp extract_ssrn(nil), do: nil

  defp extract_ssrn(text) do
    case Regex.run(~r/(?:ssrn|abstract_id=)(\d{4,12})/i, text) do
      [_, ssrn_id] -> ssrn_id
      _ -> nil
    end
  end

  defp normalize_ssrn(nil), do: nil

  defp normalize_ssrn(ssrn),
    do: ssrn |> String.trim() |> String.replace(~r/\D/, "") |> blank_to_nil()

  defp extract_nber(nil), do: nil

  defp extract_nber(text) do
    case Regex.run(~r/(?:nber\.org\/(?:papers\/)?w?)(\d{4,8})/i, text) do
      [_, nber_id] -> nber_id
      _ -> nil
    end
  end

  defp normalize_nber(nil), do: nil

  defp normalize_nber(nber),
    do:
      nber
      |> String.trim()
      |> String.replace_prefix("w", "")
      |> String.replace(~r/\D/, "")
      |> blank_to_nil()

  defp extract_osf(nil), do: nil

  defp extract_osf(text) do
    case Regex.run(~r/osf\.io\/([a-z0-9]{4,12})/i, text) do
      [_, osf_id] -> osf_id
      _ -> nil
    end
  end

  defp normalize_osf(nil), do: nil
  defp normalize_osf(osf), do: osf |> String.trim() |> String.downcase() |> blank_to_nil()

  defp score_snapshot(%CanonicalRecord{} = record) do
    %{
      relevance_score: record.relevance_score,
      evidence_strength_score: record.evidence_strength_score,
      transferability_score: record.transferability_score,
      citation_quality_score: record.citation_quality_score,
      formula_actionability_score: record.formula_actionability_score
    }
  end

  defp decision_summary(
         accepted_core,
         accepted_analog,
         background,
         quarantine,
         discard_log,
         duplicate_groups,
         decision_log
       ) do
    actions = Enum.frequencies_by(decision_log, & &1.action)

    %{
      accepted_core: length(accepted_core),
      accepted_analog: length(accepted_analog),
      background: length(background),
      quarantine: length(quarantine),
      discard: length(discard_log),
      duplicate_groups: length(duplicate_groups),
      actions: actions
    }
  end

  defp sort_decisions(decisions) do
    Enum.sort_by(decisions, fn decision ->
      {
        decision.record_id,
        stage_rank(decision.stage),
        action_rank(decision.action),
        decision.classification || :none
      }
    end)
  end

  defp stage_rank(:conflation_detection), do: 0
  defp stage_rank(:duplicate_grouping), do: 1
  defp stage_rank(:classification), do: 2

  defp action_rank(:split), do: 0
  defp action_rank(:merged), do: 1
  defp action_rank(:accepted), do: 2
  defp action_rank(:downgraded), do: 3
  defp action_rank(:quarantined), do: 4
  defp action_rank(:discarded), do: 5

  defp pair_key(left_id, right_id) when left_id <= right_id, do: {left_id, right_id}
  defp pair_key(left_id, right_id), do: {right_id, left_id}

  defp stable_id(prefix, parts) do
    digest =
      parts
      |> reject_blank()
      |> Enum.join("|")
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    prefix <> ":" <> digest
  end

  defp quarantine_record_id(record_id), do: "quarantine:" <> record_id

  defp preferred_text(left, right) do
    cond do
      present?(left) and not placeholder_title?(left) -> left
      present?(right) and not placeholder_title?(right) -> right
      present?(left) -> left
      true -> right
    end
  end

  defp preferred_year(left, _right) when is_integer(left), do: left
  defp preferred_year(nil, right), do: right
  defp preferred_year(left, _right), do: left

  defp preferred_list([], right), do: right
  defp preferred_list(left, _right), do: left

  defp preferred_source_type(nil, right), do: right
  defp preferred_source_type(:unknown, right), do: right
  defp preferred_source_type(left, _right), do: left

  defp preferred_formula_status(left, right) do
    status_rank = %{exact: 5, partial: 4, referenced_only: 3, unknown: 2, none: 1}

    if Map.fetch!(status_rank, left) >= Map.fetch!(status_rank, right) do
      left
    else
      right
    end
  end

  defp with_normalized_fields(%CanonicalRecord{} = record, source_label) do
    %CanonicalRecord{
      record
      | normalized_fields: %{
          canonical_title: record.canonical_title,
          canonical_citation: record.canonical_citation,
          canonical_url: record.canonical_url,
          year: record.year,
          authors: record.authors,
          source_label: source_label,
          source_type: record.source_type,
          identifiers: Map.from_struct(record.identifiers)
        }
    }
  end

  defp shared_split_origin?(%CanonicalRecord{} = left, %CanonicalRecord{} = right) do
    left_origins = split_origins(left.raw_record_ids)
    right_origins = split_origins(right.raw_record_ids)

    left_origins != MapSet.new() and not MapSet.disjoint?(left_origins, right_origins)
  end

  defp split_origins(raw_record_ids) do
    raw_record_ids
    |> Enum.reduce(MapSet.new(), fn raw_record_id, origins ->
      case String.split(raw_record_id, ":split:", parts: 2) do
        [origin, _index] -> MapSet.put(origins, origin)
        _ -> origins
      end
    end)
  end

  defp bibliographic_identifier_count(%SourceIdentifiers{} = identifiers) do
    [identifiers.doi, identifiers.arxiv, identifiers.ssrn, identifiers.nber, identifiers.osf]
    |> Enum.count(&present?/1)
  end

  defp filled_field_count(%CanonicalRecord{} = record) do
    [
      record.canonical_title,
      record.canonical_citation,
      record.abstract,
      record.methodology_summary,
      record.findings_summary,
      record.limitations_summary,
      record.direct_product_implication,
      record.market_type
    ]
    |> Enum.count(&present?/1)
  end

  defp normalized_title_key(title) do
    title
    |> normalize_summary()
    |> case do
      nil ->
        nil

      normalized ->
        normalized
        |> String.downcase()
        |> String.replace(~r/[^[:alnum:]\s]/u, " ")
        |> String.replace(~r/\s+/u, " ")
        |> String.trim()
    end
  end

  defp placeholder_title?(nil), do: true

  defp placeholder_title?(title) when is_binary(title) do
    normalized =
      title
      |> normalized_title_key()

    is_nil(normalized) or normalized in @placeholder_titles or String.length(normalized) < 4 or
      url_string?(title)
  end

  defp significant_tokens(nil), do: MapSet.new()

  defp significant_tokens(text) do
    text
    |> String.downcase()
    |> then(&Regex.scan(~r/[[:alnum:]][[:alnum:]\-]*/u, &1))
    |> List.flatten()
    |> Enum.reject(&(String.length(&1) < 3 or MapSet.member?(@stopwords, &1)))
    |> MapSet.new()
  end

  defp year_relation(year, year) when is_integer(year), do: :same
  defp year_relation(nil, _year), do: :compatible
  defp year_relation(_year, nil), do: :compatible
  defp year_relation(_left, _right), do: :different

  defp combined_record_text(%CanonicalRecord{} = record) do
    [
      record.canonical_title,
      record.abstract,
      record.content_excerpt,
      record.methodology_summary,
      record.findings_summary,
      record.limitations_summary,
      record.direct_product_implication
    ]
    |> Enum.join(" ")
  end

  defp contains_any?(text, keywords) when is_binary(text) do
    lowered = String.downcase(text)
    Enum.any?(keywords, &String.contains?(lowered, String.downcase(&1)))
  end

  defp contains_any?(_text, _keywords), do: false

  defp maybe_increment(score, true, amount), do: score + amount
  defp maybe_increment(score, false, _amount), do: score

  defp clamp_score(score), do: max(0, min(score, 5))

  defp decode_query(nil), do: %{}
  defp decode_query(query), do: URI.decode_query(query)

  defp hostname(nil), do: nil

  defp hostname(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> String.replace_prefix(host, "www.", "")
      _ -> nil
    end
  end

  defp url_string?(value) when is_binary(value) do
    case URI.parse(String.trim(value)) do
      %URI{scheme: scheme, host: host} when is_binary(scheme) and is_binary(host) -> true
      _ -> false
    end
  end

  defp url_string?(_value), do: false

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(nil), do: false
  defp present?(_value), do: true

  defp fallback(value, fallback_value) when value in [nil, ""], do: fallback_value
  defp fallback(value, _fallback_value), do: value

  defp reject_blank(values) do
    Enum.reject(values, fn value -> not present?(value) end)
  end

  defp reject_nil(values), do: Enum.reject(values, &is_nil/1)

  defp uniq_sort(values) do
    values
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp sort_atoms(values) do
    values
    |> Enum.uniq()
    |> Enum.sort_by(&Atom.to_string/1)
  end

  defp text_length(nil), do: 0
  defp text_length(text), do: String.length(text)

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(text) do
    case String.trim(text) do
      "" -> nil
      normalized -> normalized
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
