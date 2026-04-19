# ResearchJobs

`research_jobs` owns execution boundaries for provider-backed research work.

## Synthesis Execution

The synthesis runner in `ResearchJobs.Synthesis.Runner`:

- loads finalized snapshots from `research_store`
- builds deterministic synthesis packages and inspectable request specs
- executes synthesis through a narrow provider boundary
- persists provider failures, validation failures, and completed artifacts explicitly

## Strategy Execution

The strategy runner in `ResearchJobs.Strategy.Runner`:

- loads finalized snapshots and validated synthesis artifacts
- builds deterministic strategy extraction packages
- executes formula and strategy extraction through a narrow provider boundary
- preserves accepted formulas/specs even when some provider candidates are rejected deterministically
- persists completed runs with explicit warnings instead of discarding valid artifacts because of one phantom citation

## Provider Boundary

The provider API stays narrow and boring:

- `ResearchJobs.Synthesis.Provider`
- `ResearchJobs.Synthesis.ProviderResponse`
- `ResearchJobs.Synthesis.ProviderError`
- `ResearchJobs.Synthesis.Providers.Stub`
- `ResearchJobs.Synthesis.Providers.Fake`

Strategy extraction uses the same shape:

- `ResearchJobs.Strategy.Provider`
- `ResearchJobs.Strategy.ProviderResponse`
- `ResearchJobs.Strategy.ProviderError`
- `ResearchJobs.Strategy.Providers.Instructor`
- `ResearchJobs.Strategy.Providers.Stub`
- `ResearchJobs.Strategy.Providers.Fake`

See [docs/synthesis_report_builder.md](../../docs/synthesis_report_builder.md) for the report-building lifecycle and downstream query surfaces.
