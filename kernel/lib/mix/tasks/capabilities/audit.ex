defmodule Mix.Tasks.Capabilities.Audit do
  @moduledoc false

  use Mix.Task

  @requirements ["app.config"]

  @shortdoc "Warn when capability rows lack ticket linkage"

  @impl Mix.Task
  def run(_) do
    Mix.Task.run("capabilities.check")
    Caps.load!() |> audit_caps()
    Mix.shell().info("capabilities.audit finished")
  end

  defp audit_caps(data) do
    Enum.each(List.wrap(Map.get(data, "capability", [])), fn row ->
      name = Map.get(row, "name")

      if is_binary(Map.get(row, "ticket")) do
        :ok
      else
        Mix.shell().error(["[audit] ", inspect(name), " missing ticket ref"])
      end
    end)
  end
end
