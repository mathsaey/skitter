# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Loader do
  @moduledoc false
  # This module is responsible for loading .skitter files

  alias Skitter.Runtime.Configuration
  alias Skitter.Runtime.TaskSupervisor, as: STS

  require Logger

  @doc """
  Load the file at `path`.

  A file will only be loaded once. If the file was previously loaded, the return
  value of loading that file will be returned again.
  """
  def load(path) do
    case get(path) do
      :not_present -> load_new(path)
      val -> val
    end
  end

  @doc """
  Load standard library files.

  The location of the library files is determined by
  `Skitter.Runtime.Configuration.standard_library_path/0`.

  Note that the standard library should be split into a meta and base directory.
  The meta directory is always loaded first, to ensure handlers are loaded
  before they are required by the base level.
  """
  def load_standard_library do
    load_stdlib_dir("meta")
    load_stdlib_dir("base")
  end

  defp load_stdlib_dir(dir) do
    Configuration.standard_library_path()
    |> Path.join(dir)
    |> Path.join("*.skitter")
    |> Path.wildcard()
    |> Enum.map(&Task.Supervisor.async(STS, __MODULE__, :load, [&1]))
    |> Enum.map(&Task.await(&1))
  end

  defp load_new(path) do
    Logger.debug("Loading #{path}")

    {val, _} =
      path
      |> File.read!()
      |> Code.string_to_quoted!(file: path)
      |> add_imports()
      |> Code.eval_quoted([], file: Path.relative_to_cwd(path))

    put(path, val)
    val
  end

  defp put(path, val), do: :persistent_term.put({__MODULE__, path}, val)
  defp get(path), do: :persistent_term.get({__MODULE__, path}, :not_present)

  defp add_imports(body) do
    quote do
      import Skitter.Component, only: [defcomponent: 3]
      import Skitter.Handler, only: [defhandler: 2]
      unquote(body)
    end
  end
end
