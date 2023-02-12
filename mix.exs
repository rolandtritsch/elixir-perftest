defmodule PerfTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :perftest,
      version: "1.0.0",
      elixir: "~> 1.14",
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
      {:amqp, ">= 0.0.0"}
    ]
  end
end
