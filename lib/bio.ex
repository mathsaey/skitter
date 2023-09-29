# Copyright 2018 - 2023, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.BIO do
  @moduledoc """
  Shorthands for using built-in operations.

  This module defines various macros which can be used to use the various built-in operations in
  skitter workflows.
  """

  @doc """
  `Skitter.BIO.Map` node.

  Inserts a `Skitter.BIO.Map` `Skitter.DSL.Workflow.node/2` in the workflow. The argument passed
  to this macro is passed as an argument to `Skitter.BIO.Map`, other options (`as:`, `with:`)
  should be passed as a second, optional argument.
  """
  defmacro map(func, opts \\ []) do
    opts = [args: func] ++ opts
    quote(do: node(Skitter.BIO.Map, unquote(opts)))
  end

  @doc """
  `Skitter.BIO.FlatMap` node.

  Like `map/2`, but with `Skitter.BIO.FlatMap`.
  """
  defmacro flat_map(func, opts \\ []) do
    quote(do: node(Skitter.BIO.FlatMap, unquote([args: func] ++ opts)))
  end

  @doc """
  `Skitter.BIO.Filter` node.

  Inserts a `Skitter.BIO.Filter` `Skitter.DSL.Workflow.node/2` in the workflow. The argument
  passed to this macro is passed as an argument to `Skitter.BIO.Filter`, other options (`as:`,
  `with:`) should be passed as a second, optional argument.
  """
  defmacro filter(func, opts \\ []) do
    quote(do: node(Skitter.BIO.Filter, unquote([args: func] ++ opts)))
  end

  @doc """
  `Skitter.BIO.KeyedReduce` node.

  Inserts a `Skitter.BIO.KeyedReduce` `Skitter.DSL.Workflow.node/2` in the workflow. The `key_fn`,
  `red_fn` and `initial` arguments passed to this macro are passed as arguments to
  `Skitter.BIO.KeyedReduce`. Other options (`as:`, `with:`) can be passed as a fourth argument.
  """
  defmacro keyed_reduce(key_fn, red_fn, initial, opts \\ []) do
    args =
      quote bind_quoted: [key_fn: key_fn, red_fn: red_fn, initial: initial] do
        {key_fn, red_fn, initial}
      end

    quote(do: node(Skitter.BIO.KeyedReduce, unquote([args: args] ++ opts)))
  end

  @doc """
  `Skitter.BIO.Print` node.

  Insert a `Skitter.BIO.Print` node in the workflow. The argument passed to this macro is passed
  as the print label described in the operation documentation. Workflow options (`as`, `with`) can
  be passed as the optional second argument.
  """
  defmacro print(label \\ nil, opts \\ []) do
    quote(do: node(Skitter.BIO.Print, unquote([args: label] ++ opts)))
  end

  @doc """
  `Skitter.BIO.Send` node.

  Insert a `Skitter.BIO.Send` sink in the workflow. The argument passed to this macro is passed
  as the pid described in the operation documentation. Workflow options (`as`, `with`) can
  be passed as the optional second argument. When no argument is provided, `self()` will be used.
  """
  defmacro send_sink(pid \\ quote(do: self()), opts \\ []) do
    quote(do: node(Skitter.BIO.Send, unquote([args: pid] ++ opts)))
  end

  @doc """
  Tcp source node.

  Inserts a `Skitter.BIO.TCPSource` node in the workflow. The address and ports passed to this
  argument will be passed as arguments to `Skitter.BIO.TCPSource`. Provided options are passed to
  the workflow.
  """
  defmacro tcp_source(address, port, opts \\ []) do
    opts = [args: [address: address, port: port]] ++ opts
    quote(do: node(Skitter.BIO.TCPSource, unquote(opts)))
  end

  @doc """
  Stream source node.

  Inserts a `Skitter.BIO.StreamSource` node in the workflow. The provided `enum` is passed as an
  argument to `Skitter.BIO.StreamSource`. `opts` are passed as options to the workflow.
  """
  defmacro stream_source(enum, opts \\ []) do
    quote(do: node(Skitter.BIO.StreamSource, unquote([args: enum] ++ opts)))
  end

  @doc """
  Message source node.

  Inserts a `Skitter.BIO.MessageSource` node in the workflow. Any options are passed to the
  workflow.
  """
  defmacro msg_source(opts \\ []) do
    quote(do: node(Skitter.BIO.MessageSource, unquote(opts)))
  end
end
