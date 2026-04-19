defmodule ResearchCore.Strategy.FormulaNormalizer do
  @moduledoc """
  Deterministically validates and normalizes provider-extracted formulas.
  """

  alias ResearchCore.Strategy.{EvidenceLink, FormulaCandidate, FormulaRole, Helpers, Id}

  @spec normalize(ResearchCore.Strategy.InputPackage.t(), [map() | struct()]) ::
          %{accepted: [FormulaCandidate.t()], rejected: [map()]}
  def normalize(input_package, raw_formulas) when is_list(raw_formulas) do
    raw_formulas
    |> Enum.with_index()
    |> Enum.reduce(%{accepted: [], rejected: []}, fn {raw_formula, index}, acc ->
      case normalize_formula(input_package, raw_formula, index) do
        {:ok, formula} -> %{acc | accepted: acc.accepted ++ [formula]}
        {:error, rejection} -> %{acc | rejected: acc.rejected ++ [rejection]}
      end
    end)
  end

  defp normalize_formula(input_package, raw_formula, index) do
    citation_keys =
      Helpers.fetch(raw_formula, :supporting_citation_keys, []) |> Helpers.normalize_string_list()

    section_ids = Helpers.fetch(raw_formula, :source_section_ids, []) |> normalize_section_ids()
    formula_text = Helpers.normalize_string(Helpers.fetch(raw_formula, :formula_text))
    evidence_pairs = normalize_evidence_pairs(raw_formula)

    partial? =
      truthy?(Helpers.fetch(raw_formula, :partial?, Helpers.fetch(raw_formula, :partial)))

    exact? = truthy?(Helpers.fetch(raw_formula, :exact?, Helpers.fetch(raw_formula, :exact)))
    blocked? = truthy?(Helpers.fetch(raw_formula, :blocked?, partial?))
    role = Helpers.atomize(Helpers.fetch(raw_formula, :role), FormulaRole.values(), :other)
    unknown_keys = citation_keys -- Map.keys(input_package.resolved_records)

    cond do
      formula_text == nil ->
        rejection(:malformed_formula_candidate, "formula text is required", raw_formula, :fatal)

      citation_keys == [] ->
        rejection(
          :formula_without_provenance,
          "formula must cite at least one supporting record",
          raw_formula,
          :fatal
        )

      section_ids == [] ->
        rejection(
          :formula_without_source_section,
          "formula must resolve to at least one synthesis section",
          raw_formula,
          :warning
        )

      unknown_keys != [] ->
        rejection(
          :unknown_citation_key,
          "formula references unknown citation keys: #{Enum.join(unknown_keys, ", ")}",
          raw_formula,
          :fatal,
          %{unknown_keys: unknown_keys}
        )

      exact? and partial? ->
        rejection(
          :conflicting_formula_precision,
          "formula cannot be both exact and partial",
          raw_formula,
          :fatal
        )

      partial? and not blocked? ->
        rejection(
          :partial_formula_not_blocked,
          "partial formulas must be marked blocked",
          raw_formula,
          :fatal
        )

      true ->
        with {:ok, precision} <-
               resolve_precision(
                 input_package,
                 raw_formula,
                 section_ids,
                 formula_text,
                 citation_keys,
                 exact?,
                 partial?,
                 blocked?
               ),
             {:ok, evidence_links} <-
               build_evidence_links(
                 input_package,
                 raw_formula,
                 section_ids,
                 citation_keys,
                 :supports_formula,
                 formula_text,
                 evidence_pairs
               ) do
          record_ids = Enum.map(citation_keys, &input_package.resolved_records[&1].record_id)
          section_headings = Enum.map(section_ids, &input_package.section_lookup[&1].heading)

          formula = %FormulaCandidate{
            id:
              Id.build("formula_candidate", %{
                index: index,
                section_ids: section_ids,
                citation_keys: citation_keys,
                formula_text: formula_text
              }),
            formula_text: formula_text,
            exact?: precision.exact?,
            partial?: precision.partial?,
            blocked?: precision.blocked?,
            role: role,
            symbol_glossary:
              normalize_glossary(Helpers.fetch(raw_formula, :symbol_glossary, %{})),
            source_section_ids: section_ids,
            source_section_headings: section_headings,
            supporting_citation_keys: citation_keys,
            supporting_record_ids: record_ids,
            evidence_links: evidence_links,
            notes: Helpers.normalize_notes(Helpers.fetch(raw_formula, :notes, []))
          }

          {:ok, formula}
        end
    end
  end

  defp build_evidence_links(
         input_package,
         raw_formula,
         section_ids,
         citation_keys,
         relation,
         quote,
         evidence_pairs
       ) do
    with {:ok, link_pairs} <-
           resolve_link_pairs(
             input_package,
             raw_formula,
             section_ids,
             citation_keys,
             evidence_pairs
           ) do
      links =
        Enum.map(link_pairs, fn %{
                                  section_id: section_id,
                                  citation_key: citation_key,
                                  quote: pair_quote
                                } ->
          record = Map.fetch!(input_package.resolved_records, citation_key)
          section = Map.fetch!(input_package.section_lookup, section_id)

          %EvidenceLink{
            section_id: section_id,
            section_heading: section.heading,
            citation_key: citation_key,
            record_id: record.record_id,
            relation: relation,
            quote: pair_quote || quote,
            provenance_reference: record.provenance_reference
          }
        end)

      {:ok, links}
    end
  end

  defp resolve_precision(
         input_package,
         raw_formula,
         section_ids,
         formula_text,
         citation_keys,
         exact?,
         partial?,
         blocked?
       ) do
    exact_matches = exact_formula_matches(input_package, citation_keys, formula_text)
    exact_in_sections? = exact_formula_in_sections?(input_package, section_ids, formula_text)

    cond do
      exact? and not (exact_in_sections? or exact_matches != []) ->
        rejection(
          :non_exact_formula_reference,
          "exact formulas must appear in cited synthesis sections or match exact reusable formula text from cited records",
          raw_formula,
          :fatal
        )

      partial? ->
        {:ok, %{exact?: false, partial?: true, blocked?: blocked?}}

      exact? or exact_in_sections? ->
        {:ok, %{exact?: true, partial?: false, blocked?: false}}

      true ->
        rejection(
          :ambiguous_formula_precision,
          "formula must either be explicitly partial or appear exactly in the cited synthesis sections",
          raw_formula,
          :fatal
        )
    end
  end

  defp resolve_link_pairs(_input_package, _raw_formula, _section_ids, [], _evidence_pairs),
    do: {:ok, []}

  defp resolve_link_pairs(input_package, raw_formula, section_ids, citation_keys, evidence_pairs) do
    if evidence_pairs != [] do
      validate_explicit_pairs(
        input_package,
        raw_formula,
        section_ids,
        citation_keys,
        evidence_pairs
      )
    else
      infer_link_pairs(input_package, raw_formula, section_ids, citation_keys)
    end
  end

  defp validate_explicit_pairs(
         input_package,
         raw_formula,
         section_ids,
         citation_keys,
         evidence_pairs
       ) do
    pair_section_ids = Enum.map(evidence_pairs, & &1.section_id) |> Enum.uniq()
    pair_citation_keys = Enum.map(evidence_pairs, & &1.citation_key) |> Enum.uniq()
    unknown_sections = pair_section_ids -- section_ids
    unknown_citations = pair_citation_keys -- citation_keys
    missing_citations = citation_keys -- pair_citation_keys

    cond do
      unknown_sections != [] ->
        rejection(
          :invalid_formula_evidence_pair,
          "formula evidence pairs reference undeclared source sections: #{Enum.join(Enum.map(unknown_sections, &Atom.to_string/1), ", ")}",
          raw_formula,
          :fatal,
          %{unknown_sections: Enum.map(unknown_sections, &Atom.to_string/1)}
        )

      unknown_citations != [] ->
        rejection(
          :invalid_formula_evidence_pair,
          "formula evidence pairs reference undeclared citation keys: #{Enum.join(unknown_citations, ", ")}",
          raw_formula,
          :fatal,
          %{unknown_citation_keys: unknown_citations}
        )

      Enum.any?(evidence_pairs, fn pair ->
        not section_cites_key?(input_package, pair.section_id, pair.citation_key)
      end) ->
        rejection(
          :unlinked_formula_provenance,
          "formula evidence pairs must match actual section citations",
          raw_formula,
          :fatal,
          %{
            invalid_pairs:
              Enum.map(evidence_pairs, fn pair ->
                %{section_id: Atom.to_string(pair.section_id), citation_key: pair.citation_key}
              end)
          }
        )

      missing_citations != [] ->
        rejection(
          :unlinked_formula_provenance,
          "formula citations must each map to an explicit section/citation pair",
          raw_formula,
          :fatal,
          %{unlinked_keys: missing_citations}
        )

      true ->
        {:ok, evidence_pairs}
    end
  end

  defp infer_link_pairs(input_package, raw_formula, section_ids, citation_keys) do
    citation_keys
    |> Enum.reduce_while({:ok, []}, fn citation_key, {:ok, acc} ->
      matching_sections =
        Enum.filter(section_ids, &section_cites_key?(input_package, &1, citation_key))

      case matching_sections do
        [section_id] ->
          {:cont,
           {:ok, acc ++ [%{section_id: section_id, citation_key: citation_key, quote: nil}]}}

        [] ->
          {:halt,
           rejection(
             :unlinked_formula_provenance,
             "formula citations must appear in at least one cited source section: #{citation_key}",
             raw_formula,
             :fatal,
             %{
               unlinked_keys: [citation_key],
               source_section_ids: Enum.map(section_ids, &Atom.to_string/1)
             }
           )}

        _many ->
          {:halt,
           rejection(
             :ambiguous_formula_provenance,
             "formula citation #{citation_key} appears in multiple source sections; explicit evidence pairs are required",
             raw_formula,
             :fatal,
             %{
               citation_key: citation_key,
               source_section_ids: Enum.map(matching_sections, &Atom.to_string/1)
             }
           )}
      end
    end)
  end

  defp exact_formula_matches(input_package, citation_keys, formula_text) do
    normalized_formula_text = canonical_formula_text(formula_text)

    Enum.flat_map(citation_keys, fn citation_key ->
      availability = Map.get(input_package.record_formula_availability, citation_key, %{})

      if Helpers.fetch(availability, :status) == :exact do
        availability
        |> Helpers.fetch(:exact_reusable_formula_texts, [])
        |> Enum.filter(&(canonical_formula_text(&1) == normalized_formula_text))
        |> Enum.map(fn exact_text -> %{citation_key: citation_key, formula_text: exact_text} end)
      else
        []
      end
    end)
  end

  defp exact_formula_in_sections?(input_package, section_ids, formula_text) do
    normalized_formula_text = canonical_formula_text(formula_text)

    Enum.any?(section_ids, fn section_id ->
      case Map.get(input_package.section_lookup, section_id) do
        nil ->
          false

        section ->
          section.body
          |> canonical_formula_text()
          |> case do
            nil -> false
            body -> String.contains?(body, normalized_formula_text)
          end
      end
    end)
  end

  defp section_cites_key?(input_package, section_id, citation_key) do
    case Map.get(input_package.section_lookup, section_id) do
      nil -> false
      section -> citation_key in section.cited_keys
    end
  end

  defp canonical_formula_text(value) do
    value
    |> Helpers.normalize_string()
    |> case do
      nil -> nil
      string -> string |> String.replace(~r/\s+/, " ")
    end
  end

  defp normalize_section_ids(section_ids) do
    section_ids
    |> Helpers.normalize_string_list()
    |> Enum.map(&Helpers.slug/1)
    |> Enum.reject(&(&1 == :unknown_section))
    |> Enum.uniq()
  end

  defp normalize_glossary(value) when is_map(value) do
    Map.new(value, fn {key, entry} -> {to_string(key), entry} end)
  end

  defp normalize_glossary(_value), do: %{}

  defp normalize_evidence_pairs(raw_formula) do
    raw_formula
    |> Helpers.fetch(:evidence_pairs, [])
    |> List.wrap()
    |> Enum.map(fn pair ->
      %{
        section_id: pair |> Helpers.fetch(:section_id) |> normalize_section_ids() |> List.first(),
        citation_key: pair |> Helpers.fetch(:citation_key) |> Helpers.normalize_string(),
        quote: Helpers.normalize_string(Helpers.fetch(pair, :quote))
      }
    end)
    |> Enum.reject(fn pair -> is_nil(pair.section_id) or is_nil(pair.citation_key) end)
    |> Enum.uniq()
  end

  defp truthy?(value), do: value in [true, "true", 1, "1"]

  defp rejection(type, message, raw_formula, severity, details \\ %{}) do
    {:error,
     %{
       type: type,
       message: message,
       severity: severity,
       raw_formula: raw_formula,
       details: details
     }}
  end
end
