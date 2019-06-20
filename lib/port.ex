# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Port do
  @moduledoc """
  Input/output interface of skitter workflows and components.

  The ports of a component or workflow define how it can receive and publish
  data. This module contains a type definition of ports (`t:t/0`) as well as
  some DSL utilities to handle ports.
  """
  alias Skitter.DSL

  @typedoc """
  A port is defined by its name, which is stored as an atom.
  """
  @type t() :: atom()

  @doc false
  def parse_list([in: ip], env), do: parse_list([in: ip, out: []], env)

  def parse_list(lst = [in: _, out: _], env) do
    lst
    |> Enum.map(&elem(&1, 1))
    |> Enum.map(fn
      lst when is_list(lst) -> lst
      any -> [any]
    end)
    |> Enum.map(fn ports -> Enum.map(ports, &DSL.name_to_atom(&1, env)) end)
    |> List.to_tuple()
  end

  def parse_list(any, env) do
    throw({:error, :invalid_port_list, any, env})
  end
end
