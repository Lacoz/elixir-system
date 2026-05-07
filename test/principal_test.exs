defmodule PrincipalTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  test "resolve extracts principal from header and infers user prefix" do
    conn =
      conn(:get, "/")
      |> put_req_header("x-principal-id", "user:alice_sk")

    assert {:ok, p} = Principal.resolve(conn)
    assert p.id == "user:alice_sk"
    assert p.type == :user
  end

  test "resolve infers types from id prefix" do
    for {id, typ} <- [
          {"team:t", :local_team},
          {"project:p", :project_team},
          {"service:s", :service_account},
          {"hq:h", :hq}
        ] do
      conn = conn(:get, "/") |> put_req_header("x-principal-id", id)
      assert {:ok, p} = Principal.resolve(conn)
      assert p.type == typ
    end
  end

  test "missing header returns unauthenticated" do
    assert {:error, :unauthenticated} = Principal.resolve(conn(:get, "/"))
  end
end
