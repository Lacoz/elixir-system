defmodule Mix.Tasks.Capabilities.Check do
  @moduledoc false

  use Mix.Task

  @shortdoc "Validate caps.toml or caps.lock against kernel_min and schema"

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_) do
    data = Caps.load!()

    unless Caps.satisfies_kernel_min?(data) do
      Mix.raise("kernel version does not satisfy kernel_min declared in caps manifest")
    end

    Enum.each(List.wrap(Map.get(data, "capability", [])), fn entry ->
      unless Map.has_key?(entry, "name"),
        do: Mix.raise("capability entry missing name #{inspect(entry)}")

      unless Map.has_key?(entry, "version"),
        do: Mix.raise("capability #{entry["name"]} missing version")
    end)

    Mix.shell().info("capabilities.check passed")
  end
end
