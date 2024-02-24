defmodule DidWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :did_web,
      version: "0.1.0",
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
      {:req, "~> 0.4.0"}
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
