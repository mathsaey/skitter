# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.RuntimeInstanceType do
  @moduledoc false

  @doc """
  Return a module supervisor which can supervise the current instance type.
  """
  @callback supervisor() :: module()

  @doc """
  Specify how the instance type should be loaded.

  When `:one` is specified, a single worker node will be selected for loading.
  Otherwise, `load` will be called on each worker node.
  """
  @callback load_method() :: :one | :all

  @doc """
  Load the runtime version of the component instance.

  The provided `pid()` should refer to a supervisor which can supervise the
  current node type, the `component` and `init_arguments` which are passed to
  this callback will be passed to `Skitter.Component.init/2`.

  This callback should initialize the component and provide some reference to
  the component which can be used by `react/2`
  """
  @callback load(pid(), Skitter.Component.t(), any()) :: any()

  @doc """
  Ask the component instance to react to incoming data.

  The first argument should be the return value of `load/2`, the second value
  should be the list of arguments which will be passed to
  `Skitter.Component.react/2`.
  """
  @callback react(any(), [any(), ...]) :: {:ok, pid(), reference()}
end
