# ResearchCore

`research_core` owns the pure domain model and deterministic logic for the research pipeline.

## Synthesis Modules

The synthesis/report builder lives here as pure, inspectable code:

- `ResearchCore.Synthesis.Profile` defines explicit versioned report profiles
- `ResearchCore.Synthesis.InputBuilder` converts finalized snapshot bundles into deterministic input packages
- `ResearchCore.Synthesis.PromptBuilder` builds inspectable request specs
- `ResearchCore.Synthesis.Validator` enforces structural, citation, and formula guardrails

## Guarantees

- stable citation keys for packaged records
- no hidden provider-specific prompt state inside the pure core layer
- validation happens before a report artifact can be accepted downstream
- report profiles stay explicit and versioned rather than generic

See [docs/synthesis_report_builder.md](../../docs/synthesis_report_builder.md) for the end-to-end report-building flow.
