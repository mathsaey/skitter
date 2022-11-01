# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Emit do
  @moduledoc false
  alias Skitter.Runtime.NodeStore
  alias Skitter.Strategy.Context
  require NodeStore
  use Skitter.Telemetry

  def emit(%Context{_skr: {:deploy, _, _}}, _, _) do
    raise(Skitter.DefinitionError, "Attempted to emit data inside a deploy hook")
  end

  def emit(ctx = %Context{_skr: {ref, idx}}, emit) do
    Telemetry.emit([:runtime, :emit], %{}, %{context: ctx, emit: emit})
    node_links = NodeStore.get(:links, ref, idx)

    Enum.each(emit, fn {out_port, enum} ->
      enum(enum, Map.fetch(node_links, out_port))
    end)
  end

  defp enum(_, :error), do: :ok
  defp enum(_, {:ok, []}), do: :ok
  defp enum(lst, {:ok, dsts}) when is_list(lst), do: Enum.each(lst, &value(dsts, &1))
  defp enum(enum, {:ok, dsts}), do: Stream.each(enum, &value(dsts, &1)) |> Stream.run()

  defp value(dsts, val) do
    Enum.each(dsts, fn {ctx, prt} ->
      Telemetry.wrap [:hook, :deliver], %{pid: self(), context: ctx, data: val, port: prt} do
        ctx.strategy.deliver(ctx, val, prt)
      end
    end)
  end
end
