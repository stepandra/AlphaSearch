# Architecture Boundaries

This umbrella is the control-plane foundation for research automation. It defines where shared domain code, orchestration, persistence, web operations, and observability belong before any retrieval or synthesis features are added.

## App Ownership

- `research_core`
  Shared structs, stable contracts, and pure domain code. Keep this app free of persistence, orchestration, Phoenix, and instrumentation-specific concerns.
- `research_jobs`
  Oban workers, queue entrypoints, and workflow orchestration. This is where future background execution for research runs belongs.
- `research_store`
  Ecto repo, control-plane schemas, and persistence adapters. This app owns Postgres-facing state and migrations.
- `research_web`
  Phoenix endpoint, ops-facing controllers, LiveView surfaces, and boot verification endpoints such as `/health`.
- `research_observability`
  Telemetry, tracing, metrics helpers, and shared instrumentation bootstrap.

## Current Dependency Direction

The dependency graph in the current `mix.exs` files is intentionally one-way:

- `research_core`: no umbrella dependencies.
- `research_observability`: no umbrella dependencies.
- `research_store`: depends on `research_core` and `research_observability`.
- `research_jobs`: depends on `research_core`, `research_store`, and `research_observability`.
- `research_web`: depends on `research_core`, `research_jobs`, `research_store`, and `research_observability`.

This keeps the flow boring and explicit:

- domain contracts live at the bottom in `research_core`
- persistence builds on those contracts in `research_store`
- orchestration builds on shared contracts plus persistence in `research_jobs`
- the ops console consumes the other bounded apps from `research_web`
- instrumentation stays reusable in `research_observability`

## Future Placement

Use these examples to place later blocks without inventing new umbrella apps too early:

- query generation: `research_core` plus `research_jobs`
- retrieval workers: `research_jobs`
- corpus records / branches / runs: `research_store`
- ops dashboards: `research_web`
- metrics and instrumentation: `research_observability`

## Forbidden Dependencies

- `research_core` must not depend on `research_store`, `research_jobs`, `research_web`, or `research_observability`.
- `research_store` must not depend on `research_jobs` or `research_web`.
- `research_jobs` must not depend on `research_web`.
- `research_observability` must not depend on `research_core`, `research_store`, `research_jobs`, or `research_web`.
- `research_web` may depend on the other apps, but it must not become the ownership home for `ResearchStore.Repo`, Oban worker implementations, or shared telemetry bootstrap.

These rules are meant to stop control-plane boundaries from tangling before later research features arrive.
