defmodule Mix.Tasks.Capabilities.Diffcheck do
  @moduledoc false

  use Mix.Task

  @requirements ["app.config"]

  @shortdoc "Fail when git diff HEAD exceeds 100 add or 100 delete lines per file"

  @skip ~r/^(_build\/|deps\/|\.tickets\/|mix\.lock|caps\.lock|kernel\/priv\/repo\/migrations\/|test\/fixtures\/)/

  @impl Mix.Task
  def run(_) do
    if workspace?() do
      {out, _} = System.cmd("git", ~w(diff --numstat HEAD), stderr_to_stdout: true)
      scan_lines(out)
      Mix.shell().info("capabilities.diffcheck ok")
    else
      Mix.shell().info("capabilities.diffcheck skipped (not a git checkout)")
    end
  end

  defp workspace? do
    match?({_txt, 0}, System.cmd("git", ["rev-parse", "--is-inside-work-tree"], stderr_to_stdout: true))
  end

  defp scan_lines(blob) do
    blob
    |> String.split("\n", trim: true)
    |> Enum.each(fn line ->
      case String.split(line, "\t") do
        [add, del, path] ->
          unless Regex.match?(@skip, path) do
            guard_sizes!(parse_count(add), parse_count(del), path)
          end

        _ ->
          :ok
      end
    end)
  end

  defp parse_count("-"), do: 0
  defp parse_count(bin) when is_binary(bin), do: String.to_integer(bin)

  defp guard_sizes!(a, d, path) when a > 100 or d > 100 do
    Mix.raise("diffcheck: #{path} (+#{a}/-#{d}) exceeds 100 lines; split per AGENTS §7.3")
  end

  defp guard_sizes!(_, _, _), do: :ok
end
