defmodule ResearchStore.Repo do
  use Ecto.Repo,
    otp_app: :research_store,
    adapter: Ecto.Adapters.Postgres
end
