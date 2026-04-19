defmodule ResearchCore.Synthesis.Validator do
  @moduledoc """
  Structural, citation, and formula guardrails for synthesized reports.
  """

  alias ResearchCore.Synthesis.{InputPackage, Profile, ValidationResult}

  @citation_regex ~r/REC_\d{4}/
  @formula_regex ~r/[=<>±×÷\/*^]/

  @spec validate(Profile.t(), InputPackage.t(), String.t()) :: ValidationResult.t()
  def validate(%Profile{} = profile, %InputPackage{} = package, markdown)
      when is_binary(markdown) do
    headings = extract_headings(markdown)
    cited_keys = extract_cited_keys(markdown)
    allowed_keys = allowed_keys(package)

    structural_errors = structural_errors(profile, package, markdown, headings)
    citation_errors = citation_errors(cited_keys, allowed_keys)
    formula_errors = formula_errors(profile, package, markdown)

    %ValidationResult{
      valid?: structural_errors == [] and citation_errors == [] and formula_errors == [],
      structural_errors: structural_errors,
      citation_errors: citation_errors,
      formula_errors: formula_errors,
      cited_keys: cited_keys,
      allowed_keys: allowed_keys,
      unknown_keys: cited_keys -- allowed_keys,
      validated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      metadata: %{
        headings: headings,
        markdown_length: String.length(markdown)
      }
    }
  end

  @spec extract_headings(String.t()) :: [String.t()]
  def extract_headings(markdown) do
    Regex.scan(~r/^##\s+(.+)$/m, markdown, capture: :all_but_first)
    |> Enum.map(&List.first/1)
  end

  @spec extract_cited_keys(String.t()) :: [String.t()]
  def extract_cited_keys(markdown) do
    @citation_regex
    |> Regex.scan(markdown)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp structural_errors(profile, package, markdown, headings) do
    allowed_headings = Enum.map(profile.section_specs, & &1.heading)

    required_headings =
      profile.section_specs |> Enum.reject(& &1.optional?) |> Enum.map(& &1.heading)

    []
    |> maybe_add(not markdown?(profile.output_format, markdown), %{
      type: :invalid_format,
      message: "report must be markdown with top-level ## section headings",
      details: %{output_format: profile.output_format}
    })
    |> maybe_add(is_nil(package.snapshot_finalized_at), %{
      type: :snapshot_not_finalized,
      message: "synthesis input package is not tied to a finalized snapshot",
      details: %{snapshot_id: package.snapshot_id}
    })
    |> Kernel.++(missing_required_section_errors(required_headings, headings))
    |> Kernel.++(ordering_errors(profile.section_specs, headings))
    |> Kernel.++(unknown_heading_errors(headings, allowed_headings, profile.disallowed_sections))
  end

  defp markdown?(:markdown, markdown), do: Regex.match?(~r/^##\s+/m, markdown)

  defp citation_errors(cited_keys, allowed_keys) do
    unknown = cited_keys -- allowed_keys

    Enum.map(unknown, fn key ->
      %{
        type: :unknown_citation_key,
        message: "report cited #{key}, but it is not present in the synthesis input package",
        details: %{citation_key: key}
      }
    end)
  end

  defp formula_errors(profile, package, markdown) do
    formula_section = extract_section_body(markdown, heading_for(profile, :reusable_formulas))
    exact_lookup = exact_formula_lookup(package)

    formula_section
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      line_keys = extract_cited_keys(line)

      cond do
        line_keys == [] ->
          []

        Regex.match?(@formula_regex, line) ->
          Enum.flat_map(line_keys, fn key ->
            if Map.get(exact_lookup, key, false) do
              []
            else
              [
                %{
                  type: :non_exact_formula_reference,
                  message:
                    "#{key} is presented with formula-like text, but the snapshot does not carry exact reusable formulas for that record",
                  details: %{citation_key: key, line_number: line_number}
                }
              ]
            end
          end)

        true ->
          []
      end
    end)
  end

  defp missing_required_section_errors(required_headings, headings) do
    required_headings
    |> Enum.reject(&(&1 in headings))
    |> Enum.map(fn heading ->
      %{
        type: :missing_required_section,
        message: "required section `#{heading}` is missing",
        details: %{heading: heading}
      }
    end)
  end

  defp ordering_errors(section_specs, headings) do
    positions = Map.new(Enum.with_index(headings), fn {heading, index} -> {heading, index} end)

    section_specs
    |> Enum.map(& &1.heading)
    |> Enum.filter(&Map.has_key?(positions, &1))
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [left, right] ->
      if positions[left] > positions[right] do
        [
          %{
            type: :section_order_violation,
            message: "section `#{left}` appears after `#{right}`",
            details: %{left: left, right: right}
          }
        ]
      else
        []
      end
    end)
  end

  defp unknown_heading_errors(headings, allowed_headings, disallowed_sections) do
    headings
    |> Enum.flat_map(fn heading ->
      cond do
        heading in disallowed_sections ->
          [
            %{
              type: :disallowed_section,
              message: "section `#{heading}` is explicitly disallowed for this profile",
              details: %{heading: heading}
            }
          ]

        heading not in allowed_headings ->
          [
            %{
              type: :unknown_section,
              message: "section `#{heading}` is not part of the explicit profile",
              details: %{heading: heading}
            }
          ]

        true ->
          []
      end
    end)
  end

  defp exact_formula_lookup(package) do
    (package.accepted_core ++ package.accepted_analog ++ package.background)
    |> Map.new(fn record ->
      {record.citation_key,
       record.formula.status == :exact and record.formula.exact_reusable_formula_texts != []}
    end)
  end

  defp heading_for(profile, id) do
    profile.section_specs
    |> Enum.find(&(&1.id == id))
    |> case do
      nil -> nil
      section -> section.heading
    end
  end

  defp extract_section_body(_markdown, nil), do: ""

  defp extract_section_body(markdown, heading) do
    case Regex.run(~r/^##\s+#{Regex.escape(heading)}\s*$\n(?<body>.*?)(?=^##\s+|\z)/ms, markdown,
           capture: :all_names
         ) do
      [body] -> body
      _ -> ""
    end
  end

  defp allowed_keys(package) do
    package.citation_keys
    |> Enum.map(& &1.key)
    |> Enum.sort()
  end

  defp maybe_add(errors, true, error), do: errors ++ [error]
  defp maybe_add(errors, false, _error), do: errors
end
