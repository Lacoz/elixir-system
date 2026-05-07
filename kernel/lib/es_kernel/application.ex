defmodule EsKernel.Application do
  @moduledoc false
  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      EsKernel.Repo,
      {GrantRegistry.Server, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: EsKernel.Supervisor)
  end
end
