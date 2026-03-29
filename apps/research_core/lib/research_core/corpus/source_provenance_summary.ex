defmodule ResearchCore.Corpus.SourceProvenanceSummary do
  @moduledoc """
  Shared provenance surface for canonical and merged corpus records.
  """

  defstruct providers: [],
            retrieval_run_ids: [],
            raw_record_ids: [],
            query_texts: [],
            source_urls: [],
            branch_kinds: [],
            branch_labels: [],
            merged_from_canonical_ids: []

  @type t :: %__MODULE__{
          providers: [atom()],
          retrieval_run_ids: [String.t()],
          raw_record_ids: [String.t()],
          query_texts: [String.t()],
          source_urls: [String.t()],
          branch_kinds: [atom()],
          branch_labels: [String.t()],
          merged_from_canonical_ids: [String.t()]
        }
end
