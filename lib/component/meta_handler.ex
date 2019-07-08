# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.MetaHandler do
  @moduledoc false

  import Skitter.Component.Handler.Utils
  import Skitter.Component.Callback, only: [defcallback: 4]

  def on_define(component) do
    component
    |> default_callback(:on_define, defcallback([], [], [c], do: c))
    |> default_callback(:on_instantiate, defcallback([], [], [i], do: i))
    |> require_callback(:on_define, arity: 1)
    |> require_callback(:on_instantiate, arity: 1)
  end

  def on_instantiate(instance) do
    instance
  end
end
