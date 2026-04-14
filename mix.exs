defmodule Honchox.MixProject do
  use Mix.Project

  @source_url "https://github.com/go-waylo/honchox"
  @version "0.1.0"

  def project do
    [
      app: :honchox,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      name: "Honchox",
      description: "Req-based Elixir client for the Honcho v3 API.",
      source_url: @source_url,
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Honchox.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: extras(),
      groups_for_modules: groups_for_modules(),
      groups_for_extras: groups_for_extras()
    ]
  end

  defp extras do
    [
      "README.md",
      "guides/getting-started.md",
      "guides/scoped-keys.md",
      "guides/cheatsheet.cheatmd"
    ]
  end

  defp groups_for_modules do
    [
      Client: [Honchox],
      Resources: [
        Honchox.Workspaces,
        Honchox.Peers,
        Honchox.Sessions,
        Honchox.Conclusions,
        Honchox.Keys
      ],
      "High-level": [Honchox.PeerWorkspaceQA],
      "Legacy / Compat": [Honchox.Observations],
      Errors: [Honchox.Error]
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ["README.md", "guides/getting-started.md"],
      Guides: ["guides/scoped-keys.md"],
      Reference: ["guides/cheatsheet.cheatmd"]
    ]
  end
end
