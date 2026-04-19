# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :research_store,
  ecto_repos: [ResearchStore.Repo],
  generators: [timestamp_type: :utc_datetime]

config :research_jobs, Oban,
  repo: ResearchStore.Repo,
  notifier: Oban.Notifiers.PG,
  plugins: [],
  queues: [
    control: 10,
    orchestration: 10,
    maintenance: 5
  ]

config :research_jobs, ResearchJobs.Retrieval.ProviderConfig,
  search_provider_order: [:serper, :brave, :tavily, :exa],
  fetch_provider: :jina,
  req_options: [
    connect_options: [timeout: 5_000],
    receive_timeout: 15_000,
    retry: [max_retries: 0]
  ],
  providers: [
    serper: [
      api_key_env: "SERPER_API_KEY",
      endpoint: "https://google.serper.dev/search"
    ],
    jina: [
      api_key_env: "JINA_API_KEY",
      endpoint: "https://r.jina.ai/http://"
    ],
    brave: [
      api_key_env: "BRAVE_API_KEY",
      endpoint: "https://api.search.brave.com/res/v1/web/search"
    ],
    tavily: [
      api_key_env: "TAVILY_API_KEY",
      endpoint: "https://api.tavily.com/search"
    ],
    exa: [
      api_key_env: "EXA_API_KEY",
      endpoint: "https://api.exa.ai/search"
    ]
  ]

config :research_jobs, ResearchJobs.Synthesis.ProviderConfig,
  default_provider: ResearchJobs.Synthesis.Providers.OpenAICompatible,
  llm: [
    api_key_env: "OPENAI_API_KEY",
    api_url: "https://api.openai.com",
    api_url_env: "OPENAI_API_URL",
    api_path: "/v1/chat/completions",
    model_env: "SYNTHESIS_LLM_MODEL",
    default_model: "gpt-4.1-mini",
    temperature: 0.2,
    http_options: [receive_timeout: 120_000]
  ]

config :research_jobs, ResearchJobs.Strategy.ProviderConfig,
  default_provider: ResearchJobs.Strategy.Providers.Instructor,
  llm: [
    adapter: Instructor.Adapters.OpenAI,
    api_key_env: "OPENAI_API_KEY",
    api_url: "https://api.openai.com",
    api_url_env: "OPENAI_API_URL",
    api_path: "/v1/chat/completions",
    model_env: "STRATEGY_LLM_MODEL",
    default_model: "gpt-4.1-mini",
    mode: :json_schema,
    max_retries: 1,
    http_options: [receive_timeout: 60_000]
  ]

config :research_observability,
  service_name: "research_platform",
  telemetry_poller_period: 10_000,
  prometheus_metrics_path: "/metrics",
  prometheus_metrics_port: 9_568

config :research_observability, ResearchObservability.Telemetry,
  reporter_name: :research_platform_metrics,
  metrics: [
    {ResearchObservability.Metrics, :phoenix_metrics, []},
    {ResearchObservability.Metrics, :repo_metrics, ["research_store.repo"]},
    {ResearchObservability.Metrics, :vm_metrics, []}
  ],
  measurements: [
    {ResearchObservability.Measurements, :default_measurements, []}
  ]

config :research_observability, ResearchObservability.Tracing,
  phoenix: [adapter: :bandit, endpoint_prefix: [:phoenix, :endpoint], liveview: true],
  bandit: [],
  ecto_event_prefixes: [[:research_store, :repo]],
  oban: :disabled

config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :none

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf

# Configure the endpoint
config :research_web, ResearchWebWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ResearchWebWeb.ErrorHTML, json: ResearchWebWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ResearchWeb.PubSub,
  live_view: [signing_salt: "cP/D7E/k"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Sample configuration:
#
#     config :logger, :default_handler,
#       level: :info
#
#     config :logger, :default_formatter,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#
