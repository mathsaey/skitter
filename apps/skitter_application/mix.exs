defmodule SkitterApplication.MixProject do
  use Mix.Project

  def project do
    {global, _} = Code.eval_file("../../global.exs")
    [app: :skitter_application] ++ global
  end
end
