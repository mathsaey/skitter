# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Application do
  @moduledoc false

  use Application
  alias Skitter.Runtime

  def start(_type, []) do
    if check_vm_features() do
      mode = Application.get_env(:skitter, :mode, :local)
      nodes = Application.get_env(:skitter, :worker_nodes, [])

      pre_load(mode, nodes)
      children = shared_children() ++ children(mode, nodes)
      Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
    else
      {:error, "Erlang/OTP version mismatch"}
    end
  end

  defp pre_load(:master, _), do: banner_if_iex()

  defp pre_load(:local, nodes) do
    banner_if_iex()

    if not Enum.empty?(nodes) do
      IO.warn("Worker nodes are ignored in local mode")
    end
  end

  defp pre_load(_, _), do: nil

  def shared_children() do
    [
      {Task.Supervisor, name: Skitter.TaskSupervisor}
    ]
  end

  defp children(:worker, _), do: [Runtime.Worker.supervisor()]
  defp children(:master, nodes), do: [Runtime.Master.supervisor(nodes)]

  defp children(:local, _) do
    children(:worker, []) ++ children(:master, Node.self())
  end

  defp check_vm_features do
    Enum.all?(
      [
        :persistent_term,
        :ets
      ],
      &Code.ensure_loaded?(&1)
    )
  end

  defp banner_if_iex do
    if IEx.started?(), do: IO.puts(banner())
  end

  defp banner do
    logo =
      if IO.ANSI.enabled?() do
        "#{IO.ANSI.italic()}⬡⬢⬡⬢ Skitter#{IO.ANSI.reset()}"
      else
        "Skitter"
      end

    "#{logo} (#{Application.spec(:skitter, :vsn)})"
  end
end
