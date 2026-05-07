defmodule CapabilityHost do
  @moduledoc false

  use GenServer

  def child_spec(app) when is_atom(app) do
    %{
      id: {:capability, app},
      start: {__MODULE__, :start_link, [app]},
      restart: :transient,
      shutdown: :infinity,
      type: :worker
    }
  end

  def start_link(app) when is_atom(app) do
    GenServer.start_link(__MODULE__, app)
  end

  @impl true
  def init(app) do
    maybe_unload_existing(app)

    with :ok <- load_application(app),
         {:ok, _} <- Application.ensure_all_started(app, :temporary) do
      {:ok, app}
    else
      {:error, _} = err -> {:stop, err}
      err -> {:stop, err}
    end
  end

  @impl true
  def terminate(_reason, app) when is_atom(app) do
    _ = Application.stop(app)
    :ok
  end

  defp maybe_unload_existing(app) do
    _ = Application.stop(app)
    _ = Application.unload(app)
    :ok
  end

  defp load_application(app) do
    case Application.load(app) do
      :ok ->
        :ok

      {:error, {:already_loaded, ^app}} ->
        :ok

      {:error, reason} ->
        {:error, {:cannot_load_capability, app, reason}}
    end
  end
end
