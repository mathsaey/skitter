# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Application do
  @moduledoc false

  use Application
  import Application, only: [get_env: 3, put_env: 3]

  alias Skitter.Runtime

  def start(_type, []) do
    if check_vm_features() do
      mode = get_env(:skitter, :mode, :local)

      pre_load(mode)
      children = children(mode)
      Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
    else
      {:error, "Erlang/OTP version mismatch"}
    end
  end

  defp pre_load(:master), do: banner_if_iex()
  defp pre_load(:local) do
    put_env(:skitter, :worker_nodes, Node.self())
    banner_if_iex()
  end
  defp pre_load(_), do: nil

  defp children(:worker), do: [Runtime.Worker.supervisor()]
  defp children(:local), do: children(:worker) ++ children(:master)

  defp children(:master) do
    [Runtime.Master.supervisor(get_env(:skitter, :worker_nodes, []))]
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
