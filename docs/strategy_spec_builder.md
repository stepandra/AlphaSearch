# Strategy Spec Builder

## What A Strategy Spec Is

A strategy spec is the machine-usable artifact produced after a validated synthesis report is converted
from prose into explicit strategy structure.

Each accepted spec answers:

- what the thesis is
- which market or domain it applies to
- the signal or rule being proposed
- which formulas are exact versus partial
- which features and datasets are required
- which execution and sizing assumptions must hold
- how downstream validation should begin
- whether the spec is actually ready for backtesting or still blocked

## How It Differs From Synthesis Text

The synthesis artifact is still research prose. It is designed for human review and auditability.

The strategy layer is narrower and stricter:

- it only runs from validated synthesis artifacts
- it keeps citation keys and report sections attached to every accepted formula/spec
- it rejects narrative filler that does not imply a testable signal or rule
- it preserves uncertainty instead of inventing missing equations
- it classifies readiness explicitly instead of implying that every idea is actionable

## Formula Representation

Formulas are persisted as explicit `formula_candidate` artifacts with:

- a stable ID
- exact formula text when it exists
- a `partial?` and `blocked?` flag when the equation is referenced but incomplete
- a formula role such as `:calibration` or `:execution`
- source section IDs/headings
- supporting citation keys and record IDs
- evidence links that point back to both report sections and snapshot provenance

Exact formulas must cite at least one real record with exact reusable-formula provenance, and the extracted formula text must match that exact reusable text.
Unknown citation keys fail validation.

## Backtest Ready Vs Blocked

`ready_for_backtest` means the extracted candidate has a usable signal/rule, valid evidence links,
non-blocked formulas, and mapped dataset/feature requirements.

Other readiness states keep uncertainty explicit:

- `needs_feature_build`
- `needs_data_mapping`
- `needs_formula_completion`
- `reject`

Actionability is derived separately as `:immediate`, `:near_term`, `:exploratory`, or `:background_only`.

## Evidence Linkage

Each formula/spec stores `evidence_link` entries that preserve:

- the synthesis section ID and heading
- the cited record key
- the canonical record ID
- the relation of that evidence to the formula/thesis/rule
- the snapshot provenance reference for the cited record

This means downstream consumers never have to guess which report paragraph or record supported a strategy.

## Snapshot To Strategy Flow

1. Load the finalized snapshot with `ResearchStore.CorpusRegistry.load_snapshot/1`.
2. Load the validated synthesis artifact with `ResearchStore.successful_synthesis_artifact/2`.
3. Build a deterministic `ResearchCore.Strategy.InputPackage` from the snapshot while cross-checking the persisted synthesis citation mapping.
4. Extract formulas through the narrow provider boundary in `research_jobs`.
5. Normalize formulas deterministically and reject unsupported or phantom-cited entries.
6. Extract strategy candidates through a second narrow provider call.
7. Normalize candidates, merge near-duplicates, classify readiness/actionability, and build `strategy_spec` artifacts.
8. Persist the extraction run, validation result, formula candidates, and strategy specs through `ResearchStore.StrategyRegistry`.

## Explicit Non-Goals

This block does not:

- rerun retrieval
- rerun corpus QA
- mutate snapshots
- mutate validated synthesis artifacts
- build knowledge-graph reasoning
- score branches
- execute backtests
- implement live trading logic
- fabricate formulas or evidence

## Next Block Consumption

The next backtest-spec block should consume only persisted strategy artifacts and should not re-interpret
raw synthesis markdown.

Useful query surfaces are:

- `ResearchStore.ready_strategy_specs_for_snapshot/2`
- `ResearchStore.strategy_specs_for_snapshot/2`
- `ResearchStore.strategy_specs_for_artifact/2`
- `ResearchStore.strategy_specs_for_branch/2`
- `ResearchStore.strategy_specs_for_theme/2`
- `ResearchStore.latest_strategy_specs_for_branch/2`
- `ResearchStore.latest_strategy_specs_for_theme/2`
- `ResearchStore.strategy_formulas_for_spec/1`
- `ResearchStore.strategy_spec_with_provenance/1`
- `ResearchStore.strategy_formulas_for_run/1`

Those consumers should treat the strategy layer as the audited boundary between research prose and executable validation planning.

## Livebook Walkthrough

For notebook-based inspection, there are now two explicit walkthroughs:

- `livebooks/strategy_spec_builder_walkthrough.livemd`
- `livebooks/retrieval_to_strategy_walkthrough.livemd`
- `livebooks/retrieval_to_strategy_walkthrough_standalone.livemd`

The strategy-only notebook exposes:

- credential injection through a setup cell
- deterministic fixture mode for safe inspection
- persisted-snapshot mode for real validated artifacts
- explicit request, raw provider output, normalization, validation, and optional persistence steps

The full retrieval-to-strategy notebook exposes:

- theme normalization and branch expansion
- query-catalog filtering before retrieval
- raw retrieval results and fetch outputs
- the raw-record bridge into corpus QA
- accepted/background/quarantine decisions before synthesis
- in-memory synthesis package construction with provenance-derived formula text
- live or fake synthesis and strategy providers with credentials injected through notebook cells
- standalone Livebook bootstrapping through `Mix.install/2` with application startup disabled so `Oban` does not boot inside the notebook runtime

## Example Shapes

```elixir
%ResearchCore.Strategy.FormulaCandidate{
  id: "formula_candidate_123",
  formula_text: "score = wins / total",
  exact?: true,
  partial?: false,
  blocked?: false,
  role: :calibration,
  supporting_citation_keys: ["REC_0001"]
}

%ResearchCore.Strategy.StrategySpec{
  id: "strategy_spec_123",
  title: "Calibration Gate",
  thesis: "Trade only when calibration exceeds the venue baseline.",
  category: :calibration_strategy,
  readiness: :ready_for_backtest,
  decision_rule: %{
    signal_or_rule: "enter when score > 0.62",
    entry_condition: "score > 0.62",
    exit_condition: "score < 0.55",
    formula_ids: ["formula_candidate_123"],
    rule_ids: ["rule_candidate_123"]
  }
}

%{
  type: :unknown_citation_key,
  severity: :fatal,
  message: "strategy candidate references unknown citation keys: REC_9999"
}
```
