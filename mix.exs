defmodule ExSyncLib.Mixfile do
  use Mix.Project

  def project do
    [
      app: :exsync_lib,
      version: "0.2.4",
      elixir: "~> 1.4",
      elixirc_paths: ["lib", "web"],
      deps: deps(),
      description: "Yet another Elixir reloader.",
      source_url: "https://github.com/axelson/exsync_lib",
      package: package(),
      docs: [
        extras: ["README.md"],
        main: "readme"
      ]
    ]
  end

  def application do
    [
      mod: {ExSyncLib.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.14", only: :docs},
      {:file_system, "~> 0.2"}
    ]
  end

  defp package do
    %{
      maintainers: ["Jason Axelson"],
      licenses: ["BSD 3-Clause"],
      links: %{"Github" => "https://github.com/axelson/exsync_lib"}
    }
  end
end
