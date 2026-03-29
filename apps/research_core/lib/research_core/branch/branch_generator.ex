defmodule ResearchCore.Branch.BranchGenerator do
  @moduledoc """
  Pure function module that generates research branches from a normalized theme.

  Given a `Normalized.t()`, produces one `Branch.t()` per branch kind (6 total),
  composing labels and rationales deterministically from theme fields.
  Query families are left empty — populated in a later pipeline step.
  """

  alias ResearchCore.Theme.Normalized
  alias ResearchCore.Branch.{Branch, BranchKind}

  @doc """
  Generates a list of `Branch.t()` for all 6 branch kinds from a normalized theme.

  Returns branches in the canonical order defined by `BranchKind.all/0`.
  """
  @spec generate(Normalized.t()) :: [Branch.t()]
  def generate(%Normalized{} = theme) do
    Enum.map(BranchKind.all(), &build_branch(&1, theme))
  end

  defp build_branch(:direct, theme) do
    %Branch{
      kind: :direct,
      label: theme.topic,
      rationale: "Direct exploration of the stated theme",
      theme_relation: "verbatim"
    }
  end

  defp build_branch(:narrower, theme) do
    qualifier = narrower_qualifier(theme)

    %Branch{
      kind: :narrower,
      label: "#{theme.topic} — #{qualifier}",
      rationale: "Narrows the theme to a more specific sub-topic for focused results",
      theme_relation: "subset"
    }
  end

  defp build_branch(:broader, theme) do
    framing = broader_framing(theme)

    %Branch{
      kind: :broader,
      label: framing,
      rationale: "Widens the framing to capture adjacent literature and context",
      theme_relation: "superset"
    }
  end

  defp build_branch(:analog, theme) do
    analog_domain = analog_domain(theme)

    %Branch{
      kind: :analog,
      label: "#{analog_domain} parallels to #{theme.topic}",
      rationale: "Explores a parallel domain for transferable patterns and insights",
      theme_relation: "analogy"
    }
  end

  defp build_branch(:mechanism, theme) do
    mechanism_focus = mechanism_focus(theme)

    %Branch{
      kind: :mechanism,
      label: "#{mechanism_focus} in #{theme.topic}",
      rationale: "Focuses on causal mechanisms underlying the theme",
      theme_relation: "mechanism"
    }
  end

  defp build_branch(:method, theme) do
    method_focus = method_focus(theme)

    %Branch{
      kind: :method,
      label: "#{method_focus} for #{theme.topic}",
      rationale: "Focuses on analytical methods applicable to the theme",
      theme_relation: "methodology"
    }
  end

  # -- Label composition helpers --

  defp narrower_qualifier(%Normalized{domain_hints: [first | _]}), do: first.label

  defp narrower_qualifier(%Normalized{objective: %{description: desc}}) when is_binary(desc),
    do: desc

  defp narrower_qualifier(%Normalized{constraints: [first | _]}), do: first.description
  defp narrower_qualifier(_theme), do: "specific aspects"

  defp broader_framing(%Normalized{domain_hints: [first | _], topic: topic}),
    do: "#{first.label} and #{topic}"

  defp broader_framing(%Normalized{topic: topic}),
    do: "general context of #{topic}"

  defp analog_domain(%Normalized{domain_hints: [_, second | _]}), do: second.label
  defp analog_domain(%Normalized{mechanism_hints: [first | _]}), do: first.label
  defp analog_domain(_theme), do: "cross-domain"

  defp mechanism_focus(%Normalized{mechanism_hints: [first | _]}), do: first.label

  defp mechanism_focus(%Normalized{objective: %{description: desc}}) when is_binary(desc),
    do: "mechanisms of #{desc}"

  defp mechanism_focus(_theme), do: "underlying mechanisms"

  defp method_focus(%Normalized{mechanism_hints: [_, second | _]}), do: second.label

  defp method_focus(%Normalized{constraints: [first | _]}),
    do: "methods constrained by #{first.description}"

  defp method_focus(_theme), do: "analytical methods"
end
