defmodule CapabilityRegistry do
  @moduledoc false

  def start_capability(name) when is_atom(name) do
    manifest = Caps.load!()

    if MapSet.member?(Caps.capability_names_set(manifest), name) do
      case capability_application(name) do
        {:ok, mod} ->
          child = %{
            id: {:capability, name},
            start: {mod, :start_link, [[]]},
            restart: :transient,
            type: :supervisor
          }

          case DynamicSupervisor.start_child(CapabilitySupervisor, child) do
            {:ok, _} -> :ok
            {:error, {:already_started, _}} -> :ok
            {:error, other} -> {:error, other}
          end

        {:error, _} = err ->
          err
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

  defp capability_application(cap_name) do
    otp_name =
      cap_name |> Atom.to_string() |> Macro.camelize() |> String.to_atom()

    mod = Module.safe_concat([otp_name, Application])

    case Code.ensure_loaded(mod) do
      {:module, _} -> {:ok, mod}
      {:error, _} -> {:error, :no_application}
    end
  rescue
    ArgumentError -> {:error, :no_application}
  end
end
