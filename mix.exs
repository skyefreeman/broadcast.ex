defmodule Broadcast.MixProject do
  use Mix.Project

  def project do
    [
      app: :broadcast,
      version: "0.2.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp description do
    """
    Broadcast is an Elixir library for posting to social media websites, currently with support for Bluesky and Mastodon.
    """
  end

  defp deps do
    [
      {:httpoison, "~> 2.2"},
      {:jason, "~> 1.4"},
      {:uuid, "~> 1.1"},
      {:ex_doc, "~> 0.36.1", only: :dev, runtime: false},
      {:mock, "~> 0.3.0", only: :test}
    ]
  end

  defp package() do
    [
      maintainers: ["Skye Freeman"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/skyefreeman/broadcast.ex",
        "Changelog" => "https://github.com/skyefreeman/broadcast.ex/blob/main/CHANGELOG.md"
      },
      files: ~w(lib mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md"
      ],
      output: "docs"
    ]
  end
end
