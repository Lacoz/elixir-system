defmodule CapabilityRegistry do
  @moduledoc false

  def start_capability(name) when is_atom(name) do
    manifest = Caps.load!()

    if MapSet.member?(Caps.capability_names_set(manifest), name) do
      case DynamicSupervisor.start_child(CapabilitySupervisor, {CapabilityHost, name}) do
        {:ok, _} ->
          :ok

        {:error, {:already_started, _}} ->
          :ok

        {:error, {:shutdown, reason}} ->
          {:error, {:boot_failed, reason}}

        {:error, other} ->
          {:error, other}
      end
    else
      {:error, :unknown_capability}
    end
  end

  def stop_capability(name) when is_atom(name) do
    child_id = {:capability, name}

    case Enum.find(DynamicSupervisor.which_children(CapabilitySupervisor), fn {id, _, _, _} ->
           id == child_id
         end) do
      nil ->
        {:error, :not_found}

      {^child_id, pid, _, _} when is_pid(pid) ->
        DynamicSupervisor.terminate_child(CapabilitySupervisor, pid)
    end
  end

  def active_capabilities do
    CapabilitySupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.flat_map(fn
      {{:capability, atom}, pid, _, _} when is_pid(pid) -> [atom]
      _ -> []
    end)
  end
end
