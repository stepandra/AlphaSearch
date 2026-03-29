defmodule ResearchWebWeb.HealthControllerTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Phoenix.ConnTest

  @endpoint ResearchWebWeb.Endpoint

  test "GET /health returns plain text ok" do
    conn = get(build_conn(), "/health")

    assert response(conn, 200) == "ok"
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end
end
