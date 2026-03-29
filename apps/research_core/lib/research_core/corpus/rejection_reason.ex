defmodule ResearchCore.Corpus.RejectionReason do
  @moduledoc """
  Hard-fail and downgrade reason codes used by corpus QA.
  """

  @reasons [
    :url_only_pseudo_citation,
    :missing_year,
    :placeholder_title,
    :incomplete_metadata,
    :missing_critical_evidence_fields,
    :unsafe_conflation,
    :thin_or_irrelevant_record,
    :weak_theory_without_empirical_support,
    :venue_specific_limited_transferability
  ]

  @type t ::
          :url_only_pseudo_citation
          | :missing_year
          | :placeholder_title
          | :incomplete_metadata
          | :missing_critical_evidence_fields
          | :unsafe_conflation
          | :thin_or_irrelevant_record
          | :weak_theory_without_empirical_support
          | :venue_specific_limited_transferability

  @spec all() :: [t()]
  def all, do: @reasons

  @spec valid?(term()) :: boolean()
  def valid?(value), do: value in @reasons
end
