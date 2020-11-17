defmodule Skitter.Remote.MixProject do
  use Mix.Project

  def project do
    {global, _} = Code.eval_file("../../global.exs")

    [
      app: :skitter_remote,
      config_path: "../../config/config.exs",
      elixirc_paths: elixirc_paths(Mix.env())
    ] ++ global
  end

  def application do
    [
      mod: {Skitter.Remote.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
