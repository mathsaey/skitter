# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.Strategy do
  @moduledoc false
  alias Skitter.Strategy, as: S
  alias Skitter.{Component, Callback}
  alias Skitter.Runtime.DeploymentStore

  def define(c = %Component{strategy: %S{define: cb}}) do
    Callback.call(cb, %{}, [c]).result
  end

  def deploy(c = %Component{strategy: %S{deploy: cb}}, context, args) do
    Callback.call(cb, %{component: c, context: context}, [args]).result
  end

  def send(c = %Component{strategy: %S{send: cb}}, context, datum, port, invocation) do
    deployment = DeploymentStore.get(context.deployment_ref)[context.component_id]

    Callback.call(
      cb,
      %{component: c, context: context, deployment: deployment, invocation: invocation},
      [datum, port]
    )
  end

  def receive(component, context, message, invocation, state, tag) do
    deployment = DeploymentStore.get(context.deployment_ref)[context.component_id]

    Callback.call(
      component.strategy.receive,
      %{component: component, context: context, deployment: deployment, invocation: invocation},
      [message, state, tag]
    ).result
  end

  def drop_deployment(c = %Component{strategy: %S{drop_deployment: cb}}, deployment) do
    Callback.call(cb, %{component: c, deployment: deployment}, [])
  end
end
