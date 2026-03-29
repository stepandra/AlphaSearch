# Theme Normalization

The theme normalization layer is the intake boundary for the research pipeline. It accepts raw, unstructured research theme text and produces a structured `Normalized` struct suitable for downstream branching and query generation.

All logic lives in `apps/research_core/lib/research_core/theme/`.

## Data Structures

| Struct | Module | Required Fields | Purpose |
|--------|--------|-----------------|---------|
| `Raw` | `ResearchCore.Theme.Raw` | `raw_text` | Unprocessed user input |
| `Normalized` | `ResearchCore.Theme.Normalized` | `original_input`, `normalized_text`, `topic` | Structured output of normalization |
| `Objective` | `ResearchCore.Theme.Objective` | `description` | What the user wants to achieve |
| `Constraint` | `ResearchCore.Theme.Constraint` | `description` | Heuristic limitations or conditions (with optional best-effort `kind`) |
| `DomainHint` | `ResearchCore.Theme.DomainHint` | `label` | Financial domain (e.g. `"prediction-markets"`, `"options"`) |
| `MechanismHint` | `ResearchCore.Theme.MechanismHint` | `label` | Trading mechanism (e.g. `"order-book"`, `"routing"`) |

## What Normalization Does

`ResearchCore.Theme.Normalizer.normalize/1` performs these steps in order:

1. **Validates** — rejects `nil`, empty strings, whitespace-only input, and non-binary values
2. **Trims** — removes leading/trailing whitespace
3. **Collapses whitespace** — replaces runs of spaces, tabs, newlines with a single space
4. **Stores normalized text** — the cleaned string is stored in `normalized_text`
5. **Sets topic conservatively** — `topic` currently defaults to `normalized_text`; dedicated topic extraction is deferred
6. **Extracts domain hints** — case-insensitive, boundary-aware matching against known financial domain labels (prediction markets, options, sports betting, forex, crypto, equities, futures, fixed income, DeFi)
7. **Extracts mechanism hints** — case-insensitive, boundary-aware matching against known trading mechanism labels (order-book, routing, cross-exchange, skew, arbitrage, market-making, hedging, liquidity, volatility, mean-reversion, momentum)
8. **Extracts objective** — finds the first action keyword (help, find, look, discover, etc.) and captures the text following it
9. **Extracts heuristic constraints** — regex-based pattern matching for comparison/exclusion phrases ("better than", "without", "only", "excluding", "limited to", "must not")
10. **Preserves original input** — the verbatim input string is stored in `original_input`, untouched

## What Normalization Does NOT Do

- **Generate search queries or research branches** — that is downstream work
- **Call external APIs or LLMs** — normalization is pure and local
- **Perform semantic analysis** — extraction is keyword-based, not meaning-based
- **Guarantee exhaustive extraction** — domain/mechanism hints are best-effort from a known label set; unlisted domains will not be detected
- **Perform dedicated topic extraction** — `topic` currently falls back to `normalized_text`
- **Deduplicate or rank** — hints are returned in sorted order but not weighted
- **Handle non-English input** — labels are English-only

## Guarantees

The `Normalized` struct provides these guarantees:

- `normalized_text` is always a non-empty, trimmed, whitespace-collapsed string
- `topic` is always a non-empty string and currently equals `normalized_text`
- `original_input` is always the exact input string passed to `normalize/1`
- `domain_hints`, `mechanism_hints`, and `constraints` are always lists (possibly empty)
- `objective` is either a `%Objective{}` struct or `nil`
- Output is **deterministic** — the same input always produces the same output
- All functions are **pure** — no processes, no side effects, no state

## Error Handling

| Input | Return |
|-------|--------|
| `nil` | `{:error, :empty_input}` |
| `""` | `{:error, :empty_input}` |
| `"   "` (whitespace only) | `{:error, :whitespace_only}` |
| Non-binary (integer, list, etc.) | `{:error, :invalid_input_type}` |
| Valid string | `{:ok, %Normalized{}}` |

## Example Inputs and Outputs

### Example 1: Order-book prediction contracts

**Input:**
```
"Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?"
```

**Output:**
```elixir
{:ok, %Normalized{
  original_input: "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?",
  normalized_text: "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?",
  topic: "Can order-book state help recalibrate cheap OTM prediction contracts better than price alone?",
  domain_hints: [
    %DomainHint{label: "options"},
    %DomainHint{label: "prediction-markets"}
  ],
  mechanism_hints: [
    %MechanismHint{label: "order-book"}
  ],
  objective: %Objective{
    description: "help recalibrate cheap OTM prediction contracts better than price alone?"
  },
  constraints: [
    # Heuristic extraction; not a guaranteed structured constraint.
    %Constraint{description: "price alone?", kind: :methodological}
  ],
  notes: nil
}}
```

### Example 2: Cross-exchange routing

**Input:**
```
"Look for cross-exchange routing alpha between fragmented prediction markets"
```

**Output:**
```elixir
{:ok, %Normalized{
  original_input: "Look for cross-exchange routing alpha between fragmented prediction markets",
  normalized_text: "Look for cross-exchange routing alpha between fragmented prediction markets",
  topic: "Look for cross-exchange routing alpha between fragmented prediction markets",
  domain_hints: [
    %DomainHint{label: "prediction-markets"}
  ],
  mechanism_hints: [
    %MechanismHint{label: "cross-exchange"},
    %MechanismHint{label: "routing"}
  ],
  objective: %Objective{
    description: "for cross-exchange routing alpha between fragmented prediction markets"
  },
  constraints: [],
  notes: nil
}}
```

### Example 3: Options skew and sportsbook

**Input:**
```
"Find transferable literature from options skew and sportsbook longshot demand"
```

**Output:**
```elixir
{:ok, %Normalized{
  original_input: "Find transferable literature from options skew and sportsbook longshot demand",
  normalized_text: "Find transferable literature from options skew and sportsbook longshot demand",
  topic: "Find transferable literature from options skew and sportsbook longshot demand",
  domain_hints: [
    %DomainHint{label: "options"},
    %DomainHint{label: "sports-betting"}
  ],
  mechanism_hints: [
    %MechanismHint{label: "skew"}
  ],
  objective: %Objective{
    description: "transferable literature from options skew and sportsbook longshot demand"
  },
  constraints: [],
  notes: nil
}}
```

## Known Limitations

- **Semantic false positives remain possible**: boundary-aware matching avoids substring junk, but whole words like "options" may still match in non-financial contexts
- **First-keyword-wins for objectives**: Only the first action keyword is used for objective extraction
- **Preposition capture**: "Look for X" captures "for X" (includes the preposition)
- **Constraint granularity**: heuristic constraint extraction is pattern-based and may not capture complex multi-clause conditions

## File Inventory

```
apps/research_core/lib/research_core/theme/
├── raw.ex              # Raw theme struct
├── normalized.ex       # Normalized theme struct
├── objective.ex        # Objective struct
├── constraint.ex       # Constraint struct
├── domain_hint.ex      # Domain hint struct
├── mechanism_hint.ex   # Mechanism hint struct
└── normalizer.ex       # Normalization logic

apps/research_core/test/research_core/theme/
├── raw_test.exs
├── normalized_test.exs
├── objective_test.exs
├── constraint_test.exs
├── domain_hint_test.exs
├── mechanism_hint_test.exs
├── structs_test.exs              # Cross-struct tests
├── normalizer_test.exs           # Core normalizer tests
└── normalizer_edge_cases_test.exs # Edge case coverage
```
