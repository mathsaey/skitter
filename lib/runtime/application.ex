# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Application do
  @moduledoc """
  Application callback module.

  The layout of the Skitter supervision tree depends on the configured runtime mode. If no mode
  is specified, `:local` is assumed.

  After the application is started, the three start phases specified in the application callback
  in mix.exs are executed:
    - The first phase prints a welcome message
    - The second connects to remote nodes if possible
    - The final deploys the workflow configured by `:deploy`.
  """
  use Application
  require Logger

  alias Skitter.{Workflow, Config, Remote, Runtime}
  alias Skitter.Remote.Registry
  alias Skitter.Mode.{Worker, Master}

  @impl true
  def start(:normal, []), do: start(Runtime.mode())

  @impl true
  def start_phase(:sk_log, :normal, []), do: logger(Runtime.mode())
  def start_phase(:sk_welcome, :normal, []), do: welcome(Runtime.mode())
  def start_phase(:sk_connect, :normal, []), do: connect(Runtime.mode())
  def start_phase(:sk_deploy, :normal, []), do: deploy(Runtime.mode())

  # Application Supervision Tree
  # ----------------------------

  defp start(:local) do
    Supervisor.start_link(
      [
        {Task.Supervisor, name: Remote.TaskSupervisor},
        Runtime.WorkflowWorkerSupervisor,
        Runtime.WorkflowManagerSupervisor
      ],
      strategy: :rest_for_one,
      name: __MODULE__
    )
  end

  defp start(:master) do
    Supervisor.start_link(
      [
        Master.RemoteSupervisor,
        Runtime.WorkflowManagerSupervisor
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  defp start(:worker) do
    Supervisor.start_link(
      [
        Worker.RemoteSupervisor,
        Runtime.WorkflowWorkerSupervisor
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  # Tests take care of setting up their own supervisors as needed
  defp start(:test), do: Supervisor.start_link([], strategy: :one_for_one, name: __MODULE__)

  # Additional loggers
  # ------------------

  defp logger(mode) when mode in [:worker, :master] do
    if Config.get(:logger), do: Logger.add_handlers(:skitter)
    :ok
  end

  defp logger(_), do: :ok

  # Banner / Log
  # ------------

  defp welcome(mode) do
    Logger.info("⬡⬢⬡⬢ Skitter v#{Application.spec(:skitter, :vsn)} started in #{mode} mode")
    if Node.alive?(), do: Logger.info("Reachable at `#{Node.self()}`")
    :ok
  end

  # Connect
  # -------

  defp connect(:worker), do: validate_connect(Worker.MasterConnection.connect())
  defp connect(:master), do: validate_connect(Master.WorkerConnection.connect())

  defp connect(:local) do
    Registry.start_link()
    Registry.add(Node.self(), :master)
    Registry.add(Node.self(), :worker)
    :ok
  end

  defp connect(_), do: :ok

  defp validate_connect(:ok), do: :ok
  defp validate_connect({:error, reason}), do: {:error, {:connect, reason}}

  # Deploy
  # ------

  defp deploy(mode) when mode in [:master, :local], do: do_deploy()
  defp deploy(_), do: :ok

  defp do_deploy do
    with {:ok, fun} <- validate_config(Config.get(:deploy)),
         {:ok, wf} <- validate_result(fun.()) do
      Logger.info("Deploying #{inspect(fun)}")
      Runtime.deploy(wf)
      :ok
    end
  end

  defp validate_config(nil), do: :ok
  defp validate_config(fun) when is_function(fun, 0), do: {:ok, fun}
  defp validate_config(any), do: {:error, {:deploy, :invalid_config, any}}

  defp validate_result(wf = %Workflow{}), do: {:ok, wf}
  defp validate_result(res), do: {:error, {:deploy, :invalid_value, res}}
end
