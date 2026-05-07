defmodule Mix.Tasks.Capability.New do
  @moduledoc false

  use Mix.Task

  import Mix.Generator

  @shortdoc "Scaffold capabilities/<name>_cap (does not modify caps.toml)"

  @requirements ["compile"]

  @impl Mix.Task
  def run(argv) do
    {_opts, pos, _} = OptionParser.parse(argv, switches: [])

    slug =
      case pos do
        [s] ->
          s |> String.trim() |> normalize_slug()

        _ ->
          Mix.raise("usage: mix capability.new <name>")
      end

    unless Regex.match?(~r/^[a-z][a-z0-9_]*$/, slug) do
      Mix.raise("capability slug must match ^[a-z][a-z0-9_]*$, got #{inspect(slug)}")
    end

    otp = :"#{slug}_cap"
    mod = String.to_atom(Macro.camelize("#{slug}_cap"))
    root = Path.join(["capabilities", "#{slug}_cap"])
    lib_seg = Path.join(["lib", to_string(otp)])

    create_directory(Path.join(root, lib_seg))

    create_file(Path.join([root, "mix.exs"]), mix_tpl(mod, otp))
    create_file(Path.join([root, ".formatter.exs"]), formatter_tpl())
    create_file(Path.join([root, lib_seg, "application.ex"]), app_tpl(mod))

    Mix.shell().info("scaffolded #{root} (OTP app #{inspect(otp)})")
  end

  defp normalize_slug(raw) do
    Macro.underscore(String.trim(raw) |> String.trim_trailing("_cap"))
  end

  defp mix_tpl(mod, otp) do
    """
    defmodule #{inspect(mod)}.MixProject do
      use Mix.Project

      def project do
        [
          app: #{inspect(otp)},
          version: "0.1.0",
          elixir: "~> 1.17",
          deps: deps()
        ]
      end

      defp deps, do: []

      def application do
        [
          extra_applications: [:logger],
          mod: {#{inspect(mod)}.Application, []}
        ]
      end
    end
    """
  end

  defp formatter_tpl do
    """
    [
      import_deps: [],
      inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
    ]
    """
  end

  defp app_tpl(mod) do
    """
    defmodule #{inspect(mod)}.Application do
      @moduledoc false
      use Application

      @impl Application
      def start(_type, _args) do
        children = []
        Supervisor.start_link(children, strategy: :one_for_one, name: #{inspect(mod)}.Supervisor)
      end
    end
    """
  end
end
