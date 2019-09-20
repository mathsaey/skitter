# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Handler.Primitives.Ubiquitous do
  @moduledoc """
  Primitives that handle ubiquitous computations.

  Ubiquitous computations are computations that can be executed on any node of
  the cluster. They do not require any data to be executed, or the data that
  they need to execute is present on any cluster node and immutable.

  This module provides functions to store and retrieve ubiquitous data.
  """

  alias Skitter.Runtime.Nodes

  def put(data) do
    ref = make_ref()
    Nodes.on_all(__MODULE__, :_do_put, [data, ref])
    ref
  end

  def put(node, ref, data) do
    Nodes.on(node, __MODULE__, :_do_put, [data, ref])
  end

  @doc false
  def _do_put(data, ref), do: :persistent_term.put({__MODULE__, ref}, data)

  def put_result(func) do
    ref = make_ref()
    Nodes.on_all(__MODULE__, :_do_put_result, [func, ref])
    ref
  end

  def put_result(node, ref, func) do
    Nodes.on(node, __MODULE__, :_do_put_result, [func, ref])
  end

  @doc false
  def _do_put_result(func, ref), do: _do_put(func.(), ref)

  def get(ref), do: :persistent_term.get({__MODULE__, ref})
end
