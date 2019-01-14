# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Worker do
  @moduledoc """
  Start a Skitter worker node for the current project.

  No special configuration is needed when a worker node is started.
  Therefore, this task takes no arguments.

  If you wish to pass any arguments to the underlying elixir runtime, this task
  can be started as follows: `elixir --arg1 --arg2 -S mix skitter.worker`
  """
  @shortdoc "Start a Skitter worker node for the current project."
  use Mix.Task

  @doc false
  def run(_args), do: Mix.Tasks.Skitter.Boot.boot(:worker)
end
