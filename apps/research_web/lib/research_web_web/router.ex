defmodule ResearchWebWeb.Router do
  use ResearchWebWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ResearchWebWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ResearchWebWeb do
    get "/health", HealthController, :show
  end

  scope "/", ResearchWebWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", ResearchWebWeb do
  #   pipe_through :api
  # end
end
