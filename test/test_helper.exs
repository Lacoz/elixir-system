integration_on = System.get_env("INTEGRATION_TESTS") == "1"
exclude = if(integration_on, do: [], else: [integration: true])

ExUnit.configure(exclude: exclude)

for path <- Path.wildcard("#{__DIR__}/support/**/*.ex") do
  Code.compile_file(path)
end

ExUnit.start()
