defmodule ResearchCore.Synthesis.Artifact do
  @moduledoc """
  Finalized synthesis artifact accepted after validation.
  """

  @enforce_keys [
    :id,
    :synthesis_run_id,
    :corpus_snapshot_id,
    :profile_id,
    :format,
    :content,
    :artifact_hash
  ]
  defstruct [
    :id,
    :synthesis_run_id,
    :corpus_snapshot_id,
    :profile_id,
    :format,
    :content,
    :artifact_hash,
    :finalized_at,
    section_headings: [],
    cited_keys: [],
    summary: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          synthesis_run_id: String.t(),
          corpus_snapshot_id: String.t(),
          profile_id: String.t(),
          format: :markdown,
          content: String.t(),
          artifact_hash: String.t(),
          finalized_at: DateTime.t() | nil,
          section_headings: [String.t()],
          cited_keys: [String.t()],
          summary: map()
        }
end
