defmodule ResearchWebWeb.HealthController do
  use ResearchWebWeb, :controller

  def show(conn, _params) do
    text(conn, "ok")
  end
end
