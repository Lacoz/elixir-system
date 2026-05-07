defmodule Caps do
  @moduledoc false

  def manifest_paths do
    {Application.fetch_env!(:es_kernel, :caps_path),
     Application.fetch_env!(:es_kernel, :caps_lock_path)}
  end

  def active_source! do
    {caps_path, lock_path} = manifest_paths()

    cond do
      File.exists?(lock_path) ->
        {:lock, lock_path}

      File.exists?(caps_path) ->
        {:manifest, caps_path}

      true ->
        raise ArgumentError,
              "Neither caps.lock nor caps.toml exists (see README / AGENTS.md)."
    end
  end

  def read!({_tag, path}), do: File.read!(path)

  def decode!(toml_binary) when is_binary(toml_binary),
    do: Toml.decode!(toml_binary)

  def load! do
    active_source!() |> read!() |> decode!()
  end

  def capability_names_set(data) when is_map(data) do
    data
    |> Map.get("capability", [])
    |> List.wrap()
    |> Enum.flat_map(fn
      %{"name" => name} -> [String.to_atom(name)]
      _ -> []
    end)
    |> MapSet.new()
  end

  def kernel_min_version!(data) when is_map(data) do
    case Map.get(data, "kernel_min") do
      nil ->
        Version.parse!("0.0.0")

      v when is_binary(v) ->
        Version.parse!(v)
    end
  end

  def satisfies_kernel_min?(data) when is_map(data) do
    ours =
      Application.spec(:es_kernel, :vsn)
      |> List.to_string()
      |> Version.parse!()

    required = kernel_min_version!(data)
    Version.compare(ours, required) != :lt
  end
end
