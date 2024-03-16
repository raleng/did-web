defmodule DidWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :did_web,
      version: "0.2.1",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
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
      {:jason, "~> 1.4"},
      {:httpoison, "~> 2.2"},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Module to resolve the DID document from a Web DID."
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/raleng/did-web"}
    ]
  end
end
