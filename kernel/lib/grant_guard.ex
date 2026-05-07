defmodule GrantGuard do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, principal} <- Principal.resolve(conn),
         {:ok, partition_id} <- fetch_assign(conn, :partition_id),
         {:ok, capability} <- fetch_assign(conn, :capability),
         {:ok, action} <- fetch_assign(conn, :action),
         :allow <- GrantRegistry.authorize(principal.id, capability, action, partition_id) do
      conn
      |> assign(:principal, principal)
      |> assign(:storage_prefix, PartitionProvisioner.prefix(partition_id))
    else
      {:error, :unauthenticated} ->
        conn |> send_resp(401, "unauthenticated") |> halt()

      {:fetch_error, _key} ->
        conn |> send_resp(500, "missing assigns") |> halt()

      {:deny, :no_capability} ->
        conn |> send_resp(404, "not found") |> halt()

      {:deny, :not_provisioned} ->
        conn |> send_resp(503, "not available") |> halt()

      {:deny, _} ->
        conn |> send_resp(403, "forbidden") |> halt()
    end
  end

  defp fetch_assign(conn, key) do
    case Map.fetch(conn.assigns, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:fetch_error, key}
    end
  end
end
