defmodule Honchox.MixProject do
  use Mix.Project

  @source_url "https://github.com/go-waylo/honchox"
  @version "0.2.1"

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
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:sagents, "~> 0.7", optional: true},
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
      "docs/server-side-multi-workspace-clients.md",
      "guides/cheatsheet.cheatmd"
    ]
  end

  defp groups_for_modules do
    [
      Client: [Honchox, Honchox.Client],
      Resources: [
        Honchox.Workspace,
        Honchox.Peer,
        Honchox.Session,
        Honchox.Conclusion,
        Honchox.ConclusionScope,
        Honchox.Keys
      ],
      Integrations: [Honchox.Sagents.Tools],
      Errors: [Honchox.Error]
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ["README.md", "guides/getting-started.md"],
      Guides: ["guides/scoped-keys.md", "docs/server-side-multi-workspace-clients.md"],
      Reference: ["guides/cheatsheet.cheatmd"]
    ]
  end
end
