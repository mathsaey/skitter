# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Component.TransientInstance do
  @moduledoc false
  @behaviour Skitter.Runtime.Component.Instance

  alias Skitter.Runtime.Nodes
  alias Skitter.Runtime.Component.Instance

  def load(component, init_args) do
    ref = make_ref()
    res = Nodes.on_all(__MODULE__, :load_local, [ref, component, init_args])
    true = Enum.all?(res, &match?({:ok, ^ref}, &1))
    {:ok, %Instance{mod: __MODULE__, ref: ref}}
  end

  def load_local(ref, component, init_args) do
    {:ok, instance} = Skitter.Component.init(component, init_args)
    :ok = :persistent_term.put(ref, instance)
    {:ok, ref}
  end

  def react(%Instance{ref: inst_ref}, args) do
    ref = make_ref()
    {:ok, pid} = Task.start(__MODULE__, :task, [{inst_ref, args, self(), ref}])
    {:ok, pid, ref}
  end

  def task({inst_ref, args, dst, ref}) do
    inst = :persistent_term.get(inst_ref)
    {:ok, _, spits} = Skitter.Component.react(inst, args)
    send(dst, {:react_finished, ref, spits})
  end
end
