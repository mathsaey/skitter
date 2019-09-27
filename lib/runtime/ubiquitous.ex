# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Ubiquitous do
  @moduledoc false

  alias __MODULE__.Monitor
  alias Skitter.Runtime.Nodes

  def put(func) when is_function(func, 0) do
    ref = make_ref()
    Monitor.register(ref, func)
    Nodes.on_all(__MODULE__, :_do_put_result, [func, ref])
    ref
  end

  def put(data) do
    ref = make_ref()
    Monitor.register(ref, data)
    Nodes.on_all(__MODULE__, :_do_put, [data, ref])
    ref
  end

  def put(node, ref, func) when is_function(func, 0) do
    Nodes.on(node, __MODULE__, :_do_put_result, [func, ref])
  end

  def put(node, ref, data) do
    Nodes.on(node, __MODULE__, :_do_put, [data, ref])
  end

  def _do_put(data, ref), do: :persistent_term.put({__MODULE__, ref}, data)
  def _do_put_result(func, ref), do: _do_put(func.(), ref)

  def get(ref), do: :persistent_term.get({__MODULE__, ref})
end
