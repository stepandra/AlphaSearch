defmodule ResearchCore.Synthesis.PromptBuilder do
  @moduledoc """
  Builds explicit, inspectable synthesis request specs.
  """

  alias ResearchCore.Synthesis.{InputPackage, Profile}

  @spec build(Profile.t(), InputPackage.t()) :: map()
  def build(%Profile{} = profile, %InputPackage{} = package) do
    prompt =
      [
        intro(profile, package),
        section_rules(profile),
        citation_rules(profile),
        formula_rules(profile),
        anti_goals(profile),
        packaged_records(package),
        quarantine_summary(package)
      ]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    %{
      profile_id: profile.id,
      profile_version: profile.version,
      output_format: profile.output_format,
      section_order: Enum.map(profile.section_specs, & &1.heading),
      package_digest: package.digest,
      prompt: prompt
    }
  end

  defp intro(profile, package) do
    """
    You are synthesizing a finalized research snapshot into the explicit report profile `#{profile.id}`.

    Snapshot metadata:
    - snapshot_id: #{package.snapshot_id}
    - snapshot_label: #{package.snapshot_label || "(none)"}
    - finalized_at: #{DateTime.to_iso8601(package.snapshot_finalized_at)}
    - normalized_theme_ids: #{Enum.join(package.normalized_theme_ids, ", ")}
    - branch_ids: #{Enum.join(package.branch_ids, ", ")}
    - retrieval_run_ids: #{Enum.join(package.retrieval_run_ids, ", ")}
    - package_digest: #{package.digest}

    Output requirements:
    - Return markdown only.
    - Use the exact top-level `##` headings listed below, in order.
    - Cite only with bracketed snapshot keys like `[REC_0001]` or `[REC_0001, REC_0002]`.
    - Do not cite any source outside the provided package.
    """
  end

  defp section_rules(profile) do
    section_lines =
      profile.section_specs
      |> Enum.map(fn section ->
        optionality = if section.optional?, do: "optional", else: "required"
        subsets = section.allowed_subsets |> Enum.map(&Atom.to_string/1) |> Enum.join(", ")
        "- #{section.heading} (#{optionality}; allowed subsets: #{subsets}) — #{section.guidance}"
      end)

    ["Use these sections exactly:", Enum.join(section_lines, "\n")]
    |> Enum.join("\n")
  end

  defp citation_rules(profile) do
    ["Citation rules:", Enum.map_join(profile.citation_rules, "\n", &"- #{&1}")]
    |> Enum.join("\n")
  end

  defp formula_rules(profile) do
    ["Formula rules:", Enum.map_join(profile.formula_rules, "\n", &"- #{&1}")]
    |> Enum.join("\n")
  end

  defp anti_goals(profile) do
    ["Anti-goals:", Enum.map_join(profile.anti_goals, "\n", &"- #{&1}")]
    |> Enum.join("\n")
  end

  defp packaged_records(package) do
    [
      render_subset("Accepted Core Records", package.accepted_core),
      render_subset("Accepted Analog Records", package.accepted_analog),
      render_subset("Background Records", package.background)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp render_subset(_heading, []), do: ""

  defp render_subset(heading, records) do
    body =
      Enum.map_join(records, "\n", fn record ->
        authors = Enum.join(record.authors, ", ")
        branch_labels = Enum.join(record.provenance_reference.branch_labels, ", ")
        query_texts = Enum.join(record.provenance_reference.query_texts, " | ")
        formulas = Enum.join(record.formula.exact_reusable_formula_texts, " | ")

        """
        - #{record.citation_key} | #{record.title}
          - classification: #{record.classification}
          - citation: #{record.citation || "(missing citation text)"}
          - year: #{record.year || "unknown"}
          - authors: #{authors}
          - source_type: #{record.source_type || :unknown}
          - abstract: #{record.abstract || "(none)"}
          - methodology_summary: #{record.methodology_summary || "(none)"}
          - findings_summary: #{record.findings_summary || "(none)"}
          - limitations_summary: #{record.limitations_summary || "(none)"}
          - direct_product_implication: #{record.direct_product_implication || "(none)"}
          - formula_status: #{record.formula.status}
          - formula_note: #{record.formula.note}
          - exact_formula_texts: #{if formulas == "", do: "(none)", else: formulas}
          - provenance_branch_labels: #{if branch_labels == "", do: "(none)", else: branch_labels}
          - provenance_queries: #{if query_texts == "", do: "(none)", else: query_texts}
        """
        |> String.trim_trailing()
      end)

    [heading <> ":", body] |> Enum.join("\n")
  end

  defp quarantine_summary(%InputPackage{quarantine_summary: []}), do: ""

  defp quarantine_summary(%InputPackage{quarantine_summary: records}) do
    lines =
      Enum.map_join(records, "\n", fn record ->
        "- #{record.id} | reasons=#{Enum.join(Enum.map(record.reason_codes, &Atom.to_string/1), ",")} | raw_record_ids=#{Enum.join(record.raw_record_ids, ",")}"
      end)

    ["Quarantine Summary Metadata:", lines] |> Enum.join("\n")
  end
end
