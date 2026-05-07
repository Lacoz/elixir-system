defmodule Mix.Tasks.Capabilities.Freeze do
  @moduledoc false

  use Mix.Task

  @requirements ["app.config"]

  @shortdoc "Emit caps.lock from caps.toml plus [meta] (CI augments)"

  @impl Mix.Task
  def run(_) do
    {_caps, lock_path} = Caps.manifest_paths()
    manifest_path = manifest_path_only!()

    Mix.Task.run("capabilities.check")

    body =
      manifest_path
      |> File.read!()
      |> Caps.decode!()
      |> render_lock()

    File.write!(lock_path, body)
    Mix.shell().info("capabilities.freeze wrote #{lock_path}")
  end

  defp manifest_path_only! do
    case Caps.active_source!() do
      {:lock, _} ->
        Mix.raise(
          "freeze needs caps.toml as manifest; temporarily move caps.lock out of the way"
        )

      {:manifest, path} ->
        path
    end
  end

  defp render_lock(data) do
    schema = fetch!(data, "schema")
    kernel_min = fetch!(data, "kernel_min")
    caps = List.wrap(Map.get(data, "capability", []))

    meta_and_header = """
    [meta]
    frozen_at = "#{utc_now()}"
    built_by = "mix capabilities.freeze"
    git_sha = "#{git_sha()}"
    git_branch = "#{git_branch()}"

    schema = "#{toml_esc(schema)}"
    kernel_min = "#{toml_esc(kernel_min)}"

    """

    meta_and_header <> Enum.map_join(caps, "", &cap_block/1)
  end

  defp cap_block(cap) do
    name = fetch!(cap, "name") |> to_string()
    ver = fetch!(cap, "version") |> to_string()

    """
    [[capability]]
    name = "#{toml_esc(name)}"
    version = "#{toml_esc(ver)}"

    """
  end

  defp fetch!(map, key) do
    case Map.get(map, key) do
      nil -> Mix.raise("manifest missing #{key}")
      val -> val
    end
  end

  defp toml_esc(str) when is_binary(str) do
    str |> String.replace("\\", "\\\\") |> String.replace("\"", "\\\"")
  end

  defp utc_now do
    DateTime.utc_now() |> DateTime.truncate(:second) |> Calendar.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  defp git_sha do
    case System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _ -> "unknown"
    end
  end

  defp git_branch do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"], stderr_to_stdout: true) do
      {branch, 0} -> String.trim(branch)
      _ -> "unknown"
    end
  end
end
