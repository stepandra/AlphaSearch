# ResearchPlatform

ResearchPlatform is an Elixir umbrella that provides the control-plane foundation for an autonomous research and validation system. This block only establishes the bounded apps, Phoenix operations surface, Postgres wiring, Oban runtime, and observability bootstrap needed for later work.

See [docs/architecture.md](docs/architecture.md) for app ownership and forbidden dependency directions.

## Local Boot Workflow

Install shared dependencies from the umbrella root:

```bash
mix deps.get
```

Start the Phoenix operations app from `apps/research_web`:

```bash
cd apps/research_web
mix phx.server
```

With the server running, use these lightweight smoke checks:

```bash
curl -i http://127.0.0.1:4000/
curl -i http://127.0.0.1:4000/health
```

The current scaffold can boot Phoenix and serve `/health` even when local Postgres is unavailable. In that case `ResearchStore.Repo` will log retry noise while trying to reach `localhost:5432`, but the web endpoint still comes up for route and boot verification.

## Local Postgres Requirements

You need a reachable local Postgres instance before running commands that create, migrate, or validate the control-plane database.

From `apps/research_web`:

- `mix setup`
- `mix test`
- `mix precommit`

From `apps/research_store`:

- `mix ecto.create`
- `mix ecto.migrate`

Commands such as `mix compile` from the umbrella root and `mix phx.server` from `apps/research_web` are still useful smoke checks when Postgres is offline.

## Project Layout

- `apps/research_core` contains shared structs, pure domain modules, and stable contracts.
- `apps/research_jobs` contains Oban workers, queue entrypoints, and orchestration startup.
- `apps/research_store` contains the Ecto repo, schemas, and control-plane persistence adapters.
- `apps/research_web` contains the Phoenix endpoint, controllers, LiveView surfaces, and `/health`.
- `apps/research_observability` contains telemetry, tracing, metrics helpers, and bootstrap wiring.

This foundation intentionally excludes retrieval, corpus cleaning, synthesis, knowledge-graph, and backtest logic.
