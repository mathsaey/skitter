# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime.WorkerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Skitter.{Callback, Strategy, Component}
  alias Skitter.Runtime.Worker

  setup_all do
    callback = %Callback{
      function: fn pseudo, [pid, state, tag] ->
        send(pid, %{pseudo: pseudo, state: state, tag: tag})
        %Callback.Result{}
      end
    }

    strategy = %Strategy{
      receive_message: callback
    }

    component = %Component{strategy: strategy}

    %{callback: callback, strategy: strategy, component: component}
  end

  test "uses strategy on receiving message", %{component: component} do
    {:ok, pid} = start_supervised({Worker, [nil, component, nil, nil]})
    Worker.send(pid, self(), nil)
    assert_receive %{}
  end

  test "tag and state initialisation", %{component: component} do
    {:ok, pid} = start_supervised({Worker, [nil, component, :some_state, :some_tag]})
    Worker.send(pid, self(), nil)

    assert_receive %{
      state: :some_state,
      tag: :some_tag
    }
  end

  test "fn-based state initialisation", %{component: component} do
    {:ok, pid} = start_supervised({Worker, [nil, component, fn -> :some_state end, nil]})
    Worker.send(pid, self(), nil)

    assert_receive %{state: :some_state}
  end

  test "pseudovariables", %{component: component} do
    deployment = :dummy_deployment
    invocation = :dummy_invocation

    {:ok, pid} = start_supervised({Worker, [deployment, component, nil, nil]})
    Worker.send(pid, self(), invocation)

    assert_receive %{
      pseudo: %{
        deployment_ref: ^deployment,
        invocation_ref: ^invocation,
        component: ^component
      }
    }
  end
end
