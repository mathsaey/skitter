# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Component.MetaHandler do
  @moduledoc false

  import Skitter.Component
  import Skitter.Component.Callback, only: [defcallback: 4]

  def on_define(comp) do
    comp
    |> default_callback(:on_define, defcallback([], [], [c], do: c))
    |> require_callback(:on_define, arity: 1)
  end
end
