defmodule Principal do
  @moduledoc false

  @enforce_keys [:id, :type]
  defstruct [:id, :type]

  @type t :: %__MODULE__{id: String.t(), type: atom()}

  def resolve(%Plug.Conn{} = conn) do
    case Plug.Conn.get_req_header(conn, "x-principal-id") do
      [id | _] when is_binary(id) and id != "" ->
        {:ok, %__MODULE__{id: id, type: infer_type(id)}}

      _ ->
        {:error, :unauthenticated}
    end
  end

  def type(%__MODULE__{type: type}), do: type

  defp infer_type(<<"user:", _::binary>>), do: :user
  defp infer_type(<<"team:", _::binary>>), do: :local_team
  defp infer_type(<<"project:", _::binary>>), do: :project_team
  defp infer_type(<<"service:", _::binary>>), do: :service_account
  defp infer_type(<<"hq:", _::binary>>), do: :hq
  defp infer_type(_), do: :user
end
