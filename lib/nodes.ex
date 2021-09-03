# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Nodes do
  @moduledoc """
  Remote Skitter runtimes.
  """
  alias Skitter.Runtime.Registry

  @typedoc """
  Node tag.

  A node may be tagged with atoms which indicate properties of the node.
  """
  @type tag :: atom()

  @doc """
  Execute a function on every worker node.

  The result of each worker will be returned in a keyword list of `{worker, result}` pairs.
  """
  @spec on_all_workers((() -> any())) :: [{node(), any()}]
  def on_all_workers(fun), do: Registry.on_all(fun)

  @doc """
  Execute a function on every worker node with a given `tag`.

  The result of each worker will be returned in a keyword list of `{worker, result}` pairs.
  """
  @spec on_tagged_workers(tag(), (() -> any())) :: [{node(), any()}]
  def on_tagged_workers(tag, fun), do: Registry.on_tagged(tag, fun)

  @doc """
  Execute a function for every core on the current node.

  This can be useful to spawn a worker per core.
  """
  @spec on_all_cores((() -> any())) :: [any()]
  def on_all_cores(fun), do: Enum.map(1..System.schedulers_online(), fn _ -> fun.() end)

  @doc """
  Execute a function on every core on every worker node.

  A list of results will be returned for each worker node. These results will be returned in a
  keyword list of `{worker, result}` pairs.
  """
  @spec on_all_worker_cores((() -> any())) :: [{node(), [any()]}]
  def on_all_worker_cores(fun), do: on_all_workers(fn -> on_all_cores(fun) end)

  @doc """
  Get the name of the current node.
  """
  @spec self() :: node()
  def self(), do: Node.self()

  @doc """
  Get a list of all the workers in the cluster.
  """
  @spec workers() :: [node()]
  def workers(), do: Registry.all()

  @doc """
  Get a list of all workers with a `t:tag/0`
  """
  @spec with_tag(tag()) :: [node()]
  def with_tag(tag), do: Registry.with_tag(tag)

  @doc """
  Get a list of all the tags of `node()`.
  """
  @spec tags(node()) :: [tag()]
  def tags(node), do: Registry.tags(node)
end
