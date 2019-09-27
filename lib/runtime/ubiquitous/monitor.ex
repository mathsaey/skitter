defmodule Skitter.Runtime.Ubiquitous.Monitor do
  @moduledoc false
  # Ensures ubiquitous computations are present everywhere
  # requires ubiquitous data to be stored on master node

  use GenServer

  # --- #
  # API #
  # --- #

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def register(ref, data), do: GenServer.cast(__MODULE__, {ref, data})

  # ------ #
  # Server #
  # ------ #

  def init(_) do
    Skitter.Runtime.Nodes.subscribe_join()
    {:ok, %{}}
  end

  def handle_cast({ref, data}, map), do: {:noreply, Map.put(map, ref, data)}

  def handle_info({:node_join, node}, map) do
    for {ref, data} <- map, do: Skitter.Runtime.Ubiquitous.put(node, ref, data)
    {:noreply, map}
  end
end
