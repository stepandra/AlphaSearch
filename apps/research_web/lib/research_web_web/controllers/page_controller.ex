defmodule ResearchWebWeb.PageController do
  use ResearchWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
