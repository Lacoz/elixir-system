defmodule GrantGuardTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  test "halts with 401 when principal missing" do
    conn =
      conn(:get, "/")
      |> assign(:partition_id, "sk")
      |> assign(:capability, :issues_cap)
      |> assign(:action, :read)

    conn = GrantGuard.call(conn, [])
    assert conn.halted
    assert conn.status == 401
  end

  test "halts with 500 when assigns missing" do
    conn =
      conn(:get, "/")
      |> put_req_header("x-principal-id", "user:x")
      |> assign(:partition_id, "sk")
      |> assign(:capability, :issues_cap)

    conn = GrantGuard.call(conn, [])
    assert conn.halted
    assert conn.status == 500
  end
end
