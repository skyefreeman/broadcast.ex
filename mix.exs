defmodule Broadcast.MixProject do
  use Mix.Project

  def project do
    [
      app: :broadcast,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
	main: "readme",
	extras: [
	  "README.md"
	],
	output: "docs"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 2.2"},
      {:jason, "~> 1.4"},
      {:uuid, "~> 1.1"},
      {:ex_doc, "~> 0.36.1", only: :dev, runtime: false}
    ]
  end
end
