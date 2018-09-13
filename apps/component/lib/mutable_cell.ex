defmodule Skitter.Internal.MutableCell do
  @moduledoc false

  def create, do: :ets.new(__MODULE__, [:private])

  def destroy(cell), do: :ets.delete(cell)

  def write(cell, id, value), do: :ets.insert(cell, {id, value})

  def read(cell, id) do
    [{^id, res}] = :ets.lookup(cell, id)
    res
  end

  def to_keyword_list(cell), do: :ets.tab2list(cell)

  def from_keyword_list(lst) do
    cell = create()
    Enum.each(lst, fn {k, v} -> write(cell, k, v) end)
    cell
  end
end
