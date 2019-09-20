# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Handler do
  @moduledoc false

  alias Skitter.Workflow
  alias Skitter.Component

  alias Skitter.Instance.Prototype

  alias Skitter.Runtime.MetaHandler, as: M

  def on_define(e = %{handler: Meta}), do: M.on_define(e)

  def on_define(e = %{handler: handler = %Component{handler: Meta}}) do
    Component.call(handler, :on_define, %{}, [e]).publish[:elem]
  end

  def deploy(n = %Prototype{elem: %{handler: Meta}}), do: M.deploy(n)

  def deploy(n = %Prototype{elem: %{handler: handler}}) do
    deploy(%Prototype{elem: handler, args: [n]})
  end
end
