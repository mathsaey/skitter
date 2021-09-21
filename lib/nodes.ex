# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Nodes do
  @moduledoc """
  Facilities to interact with Skitter worker nodes.

  Skitter workers nodes are remote Skitter runtimes which are responsible for performing work for
  a Skitter application. This module offers functions to query the runtime system about the
  available Skitter worker runtimes and their tags. It also defines various functions, such as
  `on_all_worker_cores/1` which can be used to spawn Skitter workers distributed over the cluster
  in various different configurations.
  """
  alias Skitter.Runtime.Registry

  @typedoc """
  Worker tag.

  A worker may be started with a tag, which indicates properties of the node. For instance, a
  `:gpu` tag could be added to a node which has a gpu. Various functions in this module can be
  used to only spawn workers on nodes with given tags.
  """
  @type tag :: atom()

  @doc """
  Get the name of the current node.
  """
  @spec self() :: node()
  def self(), do: Node.self()

  @doc """
  Get a list of the names of all the worker runtimes in the cluster.
  """
  @spec workers() :: [node()]
  def workers(), do: Registry.all()

  @doc """
  Get a list of all the worker runtimes tagged with a given `t:tag/0`.
  """
  @spec with_tag(tag()) :: [node()]
  def with_tag(tag), do: Registry.with_tag(tag)

  @doc """
  Get a list of all the tags of `node()`.
  """
  @spec tags(node()) :: [tag()]
  def tags(node), do: Registry.tags(node)

  @doc """
  Execute a function on every worker runtime.

  The result of each worker will be returned in a keyword list of `{worker, result}` pairs.
  """
  @spec on_all_workers((() -> any())) :: [{node(), any()}]
  def on_all_workers(fun), do: Registry.on_all(fun)

  @doc """
  Execute a function on every core on every worker runtime.

  A list of results will be returned for each worker node. These results will be returned in a
  keyword list of `{worker, result}` pairs.
  """
  @spec on_all_worker_cores((() -> any())) :: [{node(), [any()]}]
  def on_all_worker_cores(fun), do: on_all_workers(fn -> core_times(fun) end)

  @doc """
  Execute a function n times on every worker runtime.

  A list of results will be returned for each worker node. These results will be returned in a
  keyword list of `{worker, result}` pairs.
  """
  @spec n_times_on_all_workers(pos_integer(), (() -> any())) :: [{node(), [any()]}]
  def n_times_on_all_workers(n, fun), do: on_all_workers(fn -> n_times(fun, n) end)

  @doc """
  Execute a function on every worker runtime tagged with `tag`.

  The result of each worker will be returned in a keyword list of `{worker, result}` pairs.
  """
  @spec on_tagged_workers(tag(), (() -> any())) :: [{node(), any()}]
  def on_tagged_workers(tag, fun), do: Registry.on_tagged(tag, fun)

  @doc """
  Execute a function on every core on every worker runtime tagged with `tag`.

  The result of each worker will be returned in a keyword list of `{worker, result}` pairs.
  """
  @spec on_tagged_worker_cores(tag(), (() -> any())) :: [{node(), any()}]
  def on_tagged_worker_cores(tag, fun), do: Registry.on_tagged(tag, fn -> core_times(fun) end)

  @doc """
  Execute a function n times, distributed over the available workers.

  This is handy when you wish to create n workers distributed over the cluster. The work to be
  done will be divided over the worker nodes in a round robin fashion. This behaviour may change
  in the future.
  """
  @spec on_n(pos_integer(), (() -> any())) :: [[any()]]
  def on_n(n, fun) do
    workers()
    |> Enum.shuffle()
    |> Stream.cycle()
    |> Enum.take(n)
    |> Enum.frequencies()
    |> Enum.flat_map(fn {remote, times} ->
      Skitter.Remote.on(remote, fn -> n_times(times, fun) end)
    end)
  end

  @spec n_times(pos_integer(), (() -> any())) :: [any()]
  defp n_times(n, fun), do: Enum.map(1..n, fn _ -> fun.() end)

  @spec core_times((() -> any())) :: [any()]
  defp core_times(fun), do: n_times(System.schedulers_online(), fun)
end
