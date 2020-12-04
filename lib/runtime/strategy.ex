# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Strategy do
  @moduledoc false
  alias Skitter.Strategy, as: S
  alias Skitter.{Component, Callback}

  def define(c = %Component{strategy: %S{define: cb}}) do
    Callback.call(cb, %{}, [c]).result
  end

  def deploy(c = %Component{strategy: %S{deploy: cb}}, args) do
    Callback.call(cb, %{component: c}, [args]).result
  end

  def receive_message(component, deployment_ref, invocation_ref, message, state, tag) do
    %Component{strategy: %S{receive_message: cb}} = component

    res =
      Callback.call(
        cb,
        %{component: component, deployment_ref: deployment_ref, invocation_ref: invocation_ref},
        [message, state, tag]
      )

    {res.state, res.publish}
  end
end
