# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Mix.Tasks.Skitter.Master do
  @moduledoc """
  Start a Skitter master node

  This task starts a Skitter master node. It accepts a single option (`--deploy`) and multiple
  arguments, which represent worker nodes to connect to. In order to connect to the specified
  workers, additional arguments need to be passed to the `elixir` or `iex` command used to start
  the system. More information can be found in the "Distribution Parameters" section below.

  It is not recommended to use this task in production. Consider building a release (as described
  on the [deployment page](deployment.html#releases)) instead. If mix is used anyway, be sure to
  start in production mode.

  ## Options and Arguments

  * `--deploy`, `-d`: Deploy the workflow returned by the expression.

  Besides the `--deploy` option, any other argument is interpreted as the name of a worker node.
  The master node will attempt to connect to all the specified nodes when it is starting. If this
  fails, the master exits.

  ## Distribution Parameters

  In order to connect with other Skitter nodes, the local node needs to be distributed. This task
  does not handle distribution, instead, the correct parameters should be passed to `iex` or
  `elixir`. A few examples are provided below:

  - `elixir --sname master -S mix skitter.master`
  - `iex --sname master -S mix skitter.master`.
  - `elixir --name master@hostname -S mix skitter.master`
  - `iex --name master@hostname -S mix skitter.master`.
  """
  @shortdoc "Start a Skitter master node"
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {options, workers, _} =
      OptionParser.parse(
        args,
        aliases: [d: :deploy],
        strict: [deploy: :string, shutdown_with_workers: :boolean]
      )

    workers = [workers: Enum.map(workers, &String.to_atom/1)]
    deploy = maybe_deploy(options[:deploy])
    shutdown_with_workers = maybe_shutdown_with_workers(options[:shutdown_with_workers])

    Mix.Tasks.Skitter.start(:master, workers ++ deploy ++ shutdown_with_workers)
  end

  defp maybe_deploy(nil), do: []

  defp maybe_deploy(str) do
    [
      deploy: fn ->
        case Code.eval_string(str) do
          {wf = %Skitter.Workflow{}, _} -> wf
          {val, _} -> raise "Evaluating `#{str}` returned `#{inspect(val)}`, expected a workflow."
        end
      end
    ]
  end

  defp maybe_shutdown_with_workers(nil), do: []
  defp maybe_shutdown_with_workers(val), do: [shutdown_with_workers: val]
end
