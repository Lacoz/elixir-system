defmodule CapabilityWatcher do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :worker}
  end

  @impl true
  def init(_) do
    caps_path = Application.fetch_env!(:es_kernel, :caps_path)
    dir = Path.expand(Path.dirname(caps_path))
    file = Path.basename(caps_path)

    {:ok, pid} = FileSystem.start_link(dirs: [dir])
    FileSystem.subscribe(pid)

    {:ok, %{file: file, watcher_pid: pid}}
  end

  @impl true
  def handle_info({:file_event, pid, {path, _events}}, %{file: file, watcher_pid: pid} = st) do
    if String.ends_with?(to_string(path), file) do
      Logger.info("[kernel] #{file} changed — reload manifests before restarting capabilities.")
    end

    {:noreply, st}
  end

  def handle_info({:file_event, pid, :stop}, %{watcher_pid: pid} = st), do: {:noreply, st}

  def handle_info(_, st), do: {:noreply, st}
end
