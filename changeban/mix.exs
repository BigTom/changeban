defmodule Changeban.MixProject do
  use Mix.Project

  def project do
    [
      app: :changeban,
      version: "0.1.0",




      elixir: "~> 1.10",

      start_permanent: Mix.env() == :dev,

      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Changeban, []},
      extra_applications: [:logger]
    ]
  end






  # Specifies your project dependencies.
  #
  # Run 'mix help deps' to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  # defp aliases do
  #   [
  #     setup: ["deps.get"]
  #   ]
  # end
end
