# robust trading strategy backtesting/live trading/trading framework. modular, unix philosophy. very low latency architecture, true CLOB orderbook simulation while backtesting (as reference look at NautilusTrader on Github). But it will support (Polymarket, Hyperliquid, somwhere in the Future solana and ethereum would be needed also).

## Current spec

The project is a CLI-first, Rust-centered modular trading framework for a solo quant on a single high-end local machine. The first shipped version focuses on Polymarket binary YES/NO markets and delivers high-fidelity backtesting plus paper trading, using a deterministic single-threaded-per-market simulator with realistic queue/partial-fill behavior, full latency modeling including OS/runtime jitter, normalized core events with venue-specific extensions, QuestDB for order book data, existing ClickHouse for fills/indexed data, Python strategies over Unix domain sockets with a typed binary protocol, resource-limited subprocess isolation, reproducible run manifests, batch parameter sweeps, deterministic recovery from event log plus optional checkpoints, automated parity jobs comparing backtest vs paper runs, and separate CLI commands for ingest, replay, backtest, paper, and compare. Configuration is driven primarily by YAML/TOML manifests, compare outputs produce structured reports plus terminal summaries, Hyperliquid is only at schema/adapter-design scope in v1, and live order submission is explicitly out of scope for the first release.

## Q&A history

Q: What is the first must-win use case for version 1?
A: Research/backtesting first

Q: How realistic should the backtester be initially?
A: Level 3: near-exchange-accurate full orderbook simulation

Q: Which venue should define the backtester and adapter design in v1?
A: A neutral generic CLOB core with both as thin adapters

Q: What should the performance-critical core be built in?
A: Rust core with bindings/CLI around it

Q: What market data assumption should v1 backtesting use?
A: Support both raw message replay and normalized event replay

Q: How should strategies plug into the core initially?
A: External process/CLI strategy interface over streams

Q: What should the simulator guarantee in v1 about execution semantics?
A: Deterministic fills plus configurable latency/queue models

Q: For early live trading, what is the intended relationship between backtest and live runtimes?
A: Same strategy API, separate backtest and live executors

Q: Who is the primary v1 user you want to optimize for?
A: Solo quant/developer running local research

Q: What should v1 include for historical data ingestion?
A: Connectors plus a local normalized data store/format

Q: What class of strategies should v1 be best at?
A: Single-venue directional alpha / execution

Q: For live trading later, what operational model do you want to preserve from day one?
A: Hybrid: replayable event log plus optional checkpoints

Q: What latency regime should v1 optimize for most?
A: Sub-millisecond HFT-style reaction

Q: How much portfolio/risk management should v1 include?
A: Single-strategy with account-level risk limits

Q: What deployment assumption should shape v1 performance engineering?
A: Single high-end local machine

Q: For v1, which hard problem matters most in matching realism?
A: Queue position and partial fills

Q: Which market type should shape the core abstractions first?
A: Abstract enough for both equally from day one

Q: What should be the first strategy authoring experience?
A: Python strategies over the external process API

Q: What exact trading workflow should v1 be best at first?
A: Single-instrument execution research

Q: How much should early live-trading constraints shape v1 design?
A: Paper-trading parity should be possible in v1

Q: What should the main user-facing interface be in v1?
A: CLI-first Unix tools/pipelines

Q: How should paper trading work initially?
A: Live market data with exchange-aware simulated fills

Q: What should be the default persistence model in v1?
A: QuestDB for order book, Clickhouse for fills (we already have indexed db on clickhouse, but there is no order book L2 data, just top book). Order book now ingesting into QuestDB

Q: What operational visibility is mandatory in v1?
A: Structured logs plus metrics and event replay tooling

Q: What should be the simulator's source of truth in v1?
A: Hybrid: raw archived, normalized stream drives simulation

Q: How much of the ingestion/normalization pipeline should this project own directly?
A: Or consume existing QuestDB tables or create new configured/custom QuestDB tables, but both way - consume existing ClickHouse

Q: What should be the canonical internal event model in v1?
A: A normalized core plus venue-specific extension fields

Q: What historical market-data assumption should v1 make for accurate backtests?
A: Require full depth/order-level data when available

Q: Which latency components must v1 model explicitly?
A: Full latency stack including OS/runtime jitter

Q: What should a complete v1 workflow produce for the user?
A: Backtest plus paper-trading run with matched analytics

Q: How should v1 calibrate queue and latency realism?
A: Calibration from recorded paper/live trading observations

Q: What must match between backtest and paper trading analytics in v1?
A: PnL, fills, slippage, and latency breakdowns

Q: Which order-entry scope should v1 support end-to-end?
A: Full venue-specific order type coverage

Q: What should make a run fully reproducible in v1?
A: Strategy code/config plus exact market-data slice and simulator parameters

Q: Which venue should get full end-to-end support first?
A: Polymarket first

Q: For venue-specific behavior, what is the practical target in v1?
A: Match observed real-world behavior even if docs differ

Q: Which observed Polymarket behavior is most important to model first if docs and reality differ?
A: Queue priority and partial-fill behavior

Q: Which safety controls are mandatory even in v1 backtest/paper workflows?
A: Basic max position/notional limits only

Q: What should count as 'good enough' simulator parity in v1?
A: Within defined tolerances for fills, slippage, and latency vs paper runs

Q: How narrow should Polymarket-first scope be?
A: Binary YES/NO markets only

Q: For Polymarket v1, should the system model holding positions through market resolution, or focus only on trading before resolution?
A: both, but also include split/merge events

Q: What research workflow should v1 support beyond single backtest runs?
A: Batch parameter sweeps with comparable reports

Q: How detailed should resolution/settlement modeling be in v1?
A: Resolution, settlement, and position transition events

Q: What batch research scale should v1 handle comfortably?
A: Dozens of runs on one machine

Q: How should Polymarket YES/NO markets be represented internally in v1?
A: Canonical core plus adapter views for both representations

Q: What should Hyperliquid support look like in v1?
A: Schema/adapter design only, no full implementation yet

Q: How isolated should strategy execution be in v1?
A: Subprocesses with strict resource/time limits

Q: What should be the main rerunnable artifact produced by v1?
A: A self-contained run manifest referencing code, data slice, and simulator params

Q: What concrete performance target should v1 optimize for on one machine?
A: Fast enough for iterative research on daily slices

Q: If a paper-trading process crashes, what should v1 recovery do?
A: Restart from event log and optional checkpoint with deterministic state recovery

Q: What determinism boundary should shape the simulator core in v1?
A: Single-threaded per market, parallelize across runs/markets

Q: How should Python strategies interact with the engine in v1?
A: Async event streams with response deadlines

Q: What transport/protocol should the Python strategy interface use first?
A: Unix domain sockets with a typed binary protocol

Q: How should v1 keep simulation realism calibrated over time?
A: Automated parity jobs comparing backtest vs paper sessions

Q: What should the first-class CLI workflow be in v1?
A: Separate commands for ingest, replay, backtest, paper, and compare

Q: What should be explicitly out of scope for the first shipped version?
A: Live order submission to real venues

Q: What should be the primary configuration surface in v1?
A: YAML/TOML manifests for runs and pipelines

Q: What should the compare step produce by default?
A: Structured report plus terminal summary
