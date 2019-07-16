# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Builtins do
  @moduledoc false
  # Module responsible for loading Skitters built-in components

  @base_path "builtins"

  def load do
    load_relative_path("meta")
    load_relative_path("base")
  end

  defp load_relative_path(path) do
    @base_path
    |> Path.expand()
    |> Path.join(path)
    |> Path.join("*.skitter")
    |> Path.wildcard()
    |> Enum.each(&load_file/1)
  end

  defp load_file(path) do
    path
    |> File.read!()
    |> Code.string_to_quoted!(file: path)
    |> add_imports()
    |> Code.eval_quoted([], file: Path.relative_to_cwd(path))
  end

  defp add_imports(body) do
    quote do
      import Skitter.Component, only: [defcomponent: 3]
      import Skitter.Component.Handler, only: [defhandler: 2]
      unquote(body)
    end
  end
end
