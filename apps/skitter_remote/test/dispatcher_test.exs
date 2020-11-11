# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.DispatcherTest do
  @moduledoc false
  use Skitter.Remote.Test.ClusterCase, async: false
  alias Skitter.Remote.{Dispatcher, Test.Receiver}

  @tag distributed: [remote: [{Receiver, :start_link, [:test_mode]}]]
  test "dispatches based on mode", %{remote: remote} do
    assert :ok = Dispatcher.dispatch(remote, :test_mode, :some_message)
  end

  @tag distributed: [remote: [{Receiver, :start_link, [:default]}]]
  test "default dispatch", %{remote: remote} do
    assert :ok = Dispatcher.dispatch(remote, :test_mode, :some_message)
    assert :ok = Dispatcher.dispatch(remote, :other_mode, :some_message)
  end

  test "mode based binding" do
    Dispatcher.bind(:test_mode)
    assert Dispatcher.get_handler(:test_mode) == self()
  end

  test "default binding" do
    Dispatcher.default_bind()
    assert Dispatcher.get_handler(:test_mode) == self()
    assert Dispatcher.get_handler(:other_mode) == self()
  end
end
