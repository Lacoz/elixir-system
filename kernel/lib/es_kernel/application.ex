defmodule EsKernel.Application do
  @moduledoc false
  use Application

  @impl Application
  def start(_type, _args) do
    Supervisor.start_link([], strategy: :one_for_one, name: EsKernel.Supervisor)
  end
end
