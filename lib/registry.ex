# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Registry do
  @moduledoc false
  # Private functions to resolve component and workflow names
  alias Skitter.{Component, DefinitionError}
  use GenServer

  # --- #
  # API #
  # --- #

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def put(c = %Component{name: nil}), do: c

  def put(c = %Component{name: name}) do
    case GenServer.call(__MODULE__, {:add, c}) do
      {:error, :duplicate_name} ->
        raise DefinitionError, "`#{name}` is already in use"

      :ok ->
        c
    end
  end

  def get(key) do
    case :ets.lookup(__MODULE__, key) do
      [{_, value}] -> value
      _ -> nil
    end
  end

  # -------------- #
  # Implementation #
  # -------------- #

  def init(_) do
    table = :ets.new(__MODULE__, [:named_table, {:read_concurrency, true}])
    {:ok, table}
  end

  def handle_call({:add, c = %Component{name: name}}, _, table) do
    insert(table, name, c)
  end

  defp insert(table, key, value) do
    if :ets.insert_new(table, {key, value}) do
      {:reply, :ok, table}
    else
      {:reply, {:error, :duplicate_name}, table}
    end
  end
end