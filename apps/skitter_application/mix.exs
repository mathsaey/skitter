defmodule SkitterApplication.MixProject do
  use Mix.Project

  def project do
    {global, _} = Code.eval_file("../../global.exs")

    [
      app: :skitter_application,
      config_path: "../../config/config.exs"
    ] ++ global
  end
end
