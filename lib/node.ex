# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Node do
  @moduledoc """
  Remote Skitter runtime.
  """

  @doc """
  Execute a function on every worker node.

  The result of each worker will be returned in a keyword list of `{worker, result}` pairs.
  """
  @spec on_all_workers((() -> any())) :: [{node(), any()}]
  def on_all_workers(fun), do: Skitter.Runtime.Registry.on_all(fun)

  @doc """
  Get the name of the current node.
  """
  @spec self() :: node()
  def self(), do: Node.self()
end
