# Corpus Quality Gate

The corpus-quality gate is the strict boundary between retrieval output and downstream evidence synthesis. It takes raw `NormalizedSearchHit` plus optional `FetchedDocument` material, canonicalizes it into `ResearchCore.Corpus.CanonicalRecord`, and makes every accept, downgrade, quarantine, discard, split, and merge decision explicit.

This block is implemented in `apps/research_core/lib/research_core/corpus/` and deliberately stays pure. It does not persist corpus state, re-run retrieval, summarize literature, build graphs, or score research branches globally.

## Pipeline Stages

The QA flow is deterministic and inspectable:

1. `preprocess_raw_record/1`
   Detects likely conflated raw records. Semicolon- or pipe-separated title/citation pairs are split into explicit candidate `RawRecord` values when the split is safe. Mixed records that cannot be split safely are quarantined.
2. `canonicalize/1`
   Normalizes title, citation, URL, identifiers, authors, year, source label, evidence excerpts, and formula completeness into one `CanonicalRecord`.
3. `group_duplicates/1`
   Builds explicit `DuplicateGroup` logs using inspectable rules:
   - exact identifier match
   - exact normalized title match
   - exact canonical URL match
   - strong near-duplicate title overlap with compatible years
4. `classify_record/1`
   Applies hard-fail and soft classification rules to place each canonical record into `accepted_core`, `accepted_analog`, `background`, `quarantine`, or `discard`.

No step hides decisions behind opaque scoring. The returned `QAResult.decision_log` is the machine-readable audit trail for the whole pass.

## Canonical Model

`CanonicalRecord` keeps three layers separate:

- original retrieval provenance through `raw_record_ids` and `source_provenance_summary`
- normalized extracted fields through `normalized_fields`
- QA outcomes through `classification` and `qa_decisions`

The canonical record supports:

- `canonical_title`
- `canonical_citation`
- `year`
- `authors`
- `source_type`
- `identifiers` for DOI, arXiv, SSRN, NBER, OSF, and canonical URL
- `abstract` and `content_excerpt`
- `methodology_summary`
- `findings_summary`
- `limitations_summary`
- `direct_product_implication`
- `market_type`
- `relevance_score`
- `evidence_strength_score`
- `transferability_score`
- `citation_quality_score`
- `formula_actionability_score`
- `formula_completeness_status`
- `source_provenance_summary`

## Classification Buckets

### `accepted_core`

A record is promoted to `accepted_core` when it has direct-theme or non-analog branch provenance, strong relevance overlap, meaningful evidence fields, sufficiently canonical citation data, and transferability that is not obviously venue-bound.

### `accepted_analog`

A record is promoted to `accepted_analog` when it is clearly an analog branch artifact, still relevant, still evidence-bearing, and citation quality is high enough to trust it as a usable analog rather than vague background.

### `background`

A record is downgraded to `background` when it is structurally usable but weaker than core evidence. Typical reasons include weak theory without empirical support, venue-specific operational material, or limited transferability.

### `quarantine`

A record is quarantined when it may still matter but cannot safely pass through the gate. The current hard-fail reasons are:

- `missing_year`
- `missing_critical_evidence_fields`
- `unsafe_conflation`

### `discard`

A record is discarded when it is too malformed or too thin to justify downstream handling. The current hard-fail reasons include:

- `url_only_pseudo_citation`
- `placeholder_title`
- `incomplete_metadata`
- `thin_or_irrelevant_record`

## Formula Completeness

This block does not deeply parse formulas. It only records whether downstream synthesis can plausibly use the formula material:

- `exact`
- `partial`
- `referenced_only`
- `none`
- `unknown`

Formula status feeds the explicit `formula_actionability_score`, but it never becomes a hidden black-box ranking input.

## Guarantees

This block currently guarantees:

- raw retrieval records can be canonicalized without introducing persistence or orchestration concerns
- duplicate groups are explicit and logged through `DuplicateGroup`
- merge provenance records which canonical records were grouped, why they matched, and which representative survived
- malformed records are never silently dropped; they are quarantined or discarded with explicit reason codes
- hard-fail rules are deterministic and inspectable
- formula completeness is stored for every canonical record
- the final `QAResult` contains accepted core, accepted analog, background, quarantine, discard, duplicate groups, and an audit trail summary
- every split, merge, discard, quarantine, accept, and downgrade decision is represented in `decision_log`

## Non-Goals

This block explicitly does not do any of the following:

- literature synthesis
- hypothesis extraction
- knowledge graph construction
- global branch ranking
- retrieval retries or new search calls
- embeddings or clustering
- backtests
- final report generation

If later code needs those behaviors, it should consume `QAResult` outputs rather than expand this block into a second synthesis system.

## Example Output

```elixir
%QAResult{
  accepted_core: [
    %CanonicalRecord{
      id: "canonical-record:abc123",
      classification: :accepted_core,
      canonical_title: "Prediction Market Calibration Under Stress",
      formula_completeness_status: :exact
    }
  ],
  accepted_analog: [
    %CanonicalRecord{
      id: "canonical-record:def456",
      classification: :accepted_analog,
      canonical_title: "Options Market Calibration for Thin Liquidity"
    }
  ],
  quarantine: [
    %QuarantineRecord{
      id: "quarantine:raw-unsafe",
      reason_codes: [:unsafe_conflation]
    }
  ],
  duplicate_groups: [
    %DuplicateGroup{
      id: "duplicate-group:fedcba",
      canonical_record_id: "canonical-record:abc123",
      member_record_ids: ["canonical-record:abc123", "canonical-record:zzz999"]
    }
  ]
}
```

This output shape is intentionally narrow: it answers "which retrieved records are structurally usable for synthesis?" and nothing beyond that.
