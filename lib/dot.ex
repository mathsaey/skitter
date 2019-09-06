# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Dot do
  @moduledoc """
  Export skitter workflows as [graphviz](https://graphviz.org/) dot graphs.

  The main function in this module is the `to_dot/1` function, which accepts a
  skitter workflow and returns its dot representation as a string. End users
  may prefer the `print_dot/1` function, which immediately prints the returned
  string. If dot is installed on the system, the `export/3` function can be used
  to export the generated graph in a variety of formats.
  """
  alias Skitter.{Component, Workflow, Instance.Prototype}

  @doc """
  Return the dot representation of a workflow as a string.
  """
  @spec to_dot(Skitter.Workflow.t()) :: String.t()
  def to_dot(w = %Workflow{}), do: workflow_top(workflow: w)

  @doc """
  Print the dot representation of a workflow.
  """
  @spec print_dot(Skitter.Workflow.t()) :: :ok
  def print_dot(w = %Workflow{}), do: workflow_top(workflow: w) |> IO.puts()

  @doc """
  Export the generated dot graph, requires dot to be installed on the system.

  Besides the skitter workflow, this function accepts the path to write the
  generated file to and a list of options. Both of these arguments can be
  omitted, in which case the workflow is exported as a pdf which is saved as
  "dot.pdf" in the current working directory.

  The following options are supported:
  - `dot_exe`: the path to the dot executable, by default, this function assumes
  dot is present in your `$PATH`.
  - `format`: the output format to use. Defaults to pdf. Check the man page of
  dot to verify the supported options.
  - `extra`: a list of extra arguments to pass to the dot executable.

  ## Examples

  Save `workflow` as a png file:
  ```
  export(workflow, "myworkflow.png", format: "png")
  ```
  """
  def export(w = %Workflow{}, path \\ "dot.pdf", opts \\ []) do
    dotfile = System.tmp_dir!() |> Path.join("skitter_export.gv")
    File.write!(dotfile, to_dot(w))

    dot_exe = Keyword.get(opts, :dot_exe, "dot")
    format = Keyword.get(opts, :format, "pdf")
    extra = Keyword.get(opts, :extra, [])

    System.cmd(dot_exe, ["-T#{format}", "-o", path, dotfile] ++ extra)
    File.rm!(dotfile)
    :ok
  end

  # Templates
  # ---------

  require EEx

  # Load all templates
  __DIR__
  |> Path.join("dot/*.eex")
  |> Path.wildcard()
  |> Enum.map(fn file ->
    fname = file |> Path.basename(".eex") |> String.to_atom()
    EEx.function_from_file(:defp, fname, file, [:assigns], trim: true)
  end)

  # Path is used to avoid name conflicts in nested workflows
  defp expand_path("", id), do: Atom.to_string(id)
  defp expand_path(path, id), do: "#{path}_#{Atom.to_string(id)}"

  defp port_path("", prefix, port), do: "#{prefix}_#{port}"
  defp port_path(path, prefix, port), do: "#{path}_#{prefix}_#{port}"

  # Pattern match to treat workflows and components differently
  defp workflow_node(id, %Prototype{elem: c = %Component{}}, path) do
    component(id: id, component: c, path: path)
  end

  defp workflow_node(id, %Prototype{elem: w = %Workflow{}}, path) do
    workflow_nested(id: id, workflow: w, path: expand_path(path, id))
  end

  # Generate dot links
  defp src_address({nil, prt}, pth, wf), do: address({nil, prt}, "in", pth, wf)
  defp src_address(tup, pth, wf), do: address(tup, "out", pth, wf)

  defp dst_address({nil, prt}, pth, wf), do: address({nil, prt}, "out", pth, wf)
  defp dst_address(tup, pth, wf), do: address(tup, "in", pth, wf)

  defp address({nil, port}, prefix, path, _), do: port_path(path, prefix, port)

  defp address({id, port}, prefix, path, workflow) do
    case workflow[id].elem do
      %Component{} -> "#{expand_path(path, id)}:#{prefix}_#{port}"
      %Workflow{} -> path |> expand_path(id) |> port_path(prefix, port)
    end
  end

  # Print identifier and name if components is named
  defp component_name(%Component{name: nil}), do: ""

  defp component_name(%Component{name: n}) do
    str = n |> Module.split() |> Enum.join(".")
    "<BR/>(#{str})"
  end
end
