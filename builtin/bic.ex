# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.BIC do
  @moduledoc """
  Shorthands for using BICs.

  This module defines various macros which can be used to use the various built-in components in
  skitter workflows.
  """

  @doc """
  `Skitter.BIC.Map` node.

  Inserts a `Skitter.BIC.Map` `Skitter.DSL.Workflow.node/2` in the workflow. The argument passed
  to this macro is passed as an argument to `Skitter.BIC.Map`, other options (`as:`, `with:`)
  should be passed as a second, optional argument.
  """
  defmacro map(func, opts \\ []) do
    opts = [args: func] ++ opts
    quote(do: node(Skitter.BIC.Map, unquote(opts)))
  end

  @doc """
  `Skitter.BIC.FlatMap` node.

  Like `map/2`, but with `Skitter.BIC.FlatMap`.
  """
  defmacro flatmap(func, opts \\ []) do
    opts = [args: func] ++ opts
    quote(do: node(Skitter.BIC.FlatMap, unquote(opts)))
  end

  @doc """
  `Skitter.BIC.Print` node.

  Insert a `Skitter.BIC.Print` node in the workflow. The argument passed to this macro is passed
  as the print label described in the component documentation. Workflow options (`as`, `with`) can
  be passed as the optional second argument.
  """
  defmacro print(label, opts \\ []) do
    opts = [args: label] ++ opts
    quote(do: node(Skitter.BIC.Print, unquote(opts)))
  end

  @doc """
  tcp source node.

  Inserts a `Skitter.BIS.TCPSource` node in the workflow. The address and ports passed to this
  argument will be passed as arguments to `Skitter.BIC.TCPSource`. Provided options are passed to
  the workflow.
  """
  defmacro tcp_source(address, port, opts \\ []) do
    opts = [args: [address: address, port: port]] ++ opts
    quote(do: node(Skitter.BIC.TCPSource, unquote(opts)))
  end
end
