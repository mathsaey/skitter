# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Mode.Master.WorkerConnection do
  @moduledoc false

  alias Skitter.{Config, Remote}
  alias __MODULE__.{Registry, Notifier}

  def connect, do: connect(Config.get(:workers, []))

  def connect(worker) when is_atom(worker), do: connect([worker])

  def connect(workers) when is_list(workers) do
    case do_connect(workers) do
      [] -> :ok
      lst -> {:error, lst}
    end
  end

  defp do_connect(workers) when is_list(workers) do
    workers
    |> Enum.map(&Task.async(fn -> {&1, Remote.connect(&1, :worker)} end))
    |> Enum.map(&Task.await(&1))
    |> Enum.reject(fn {_, ret} -> ret == {:ok, :worker} end)
    |> Enum.map(fn {node, {:error, error}} -> {node, error} end)
  end

  def all, do: Registry.all()

  def connected?(worker), do: Registry.connected?(worker)

  def subscribe_up(), do: Notifier.subscribe_up()

  def subscribe_down(), do: Notifier.subscribe_down()

  def unsubscribe_up(), do: Notifier.unsubscribe_up()

  def unsubscribe_down(), do: Notifier.unsubscribe_down()

  def on_all(mod, func, args), do: Remote.on_many(all(), mod, func, args)

  def on_all(fun), do: Remote.on_many(all(), fun)
end
