# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Remote.Handler.DispatcherTest do
  @moduledoc false
  use Skitter.Remote.Test.Case
  alias(Skitter.Remote.{Handler.Dispatcher, Test.Receiver})

  test "mode based binding" do
    Dispatcher.bind(:test_mode)
    assert Dispatcher.get_handler(:test_mode) == self()
  end

  test "default binding" do
    Dispatcher.default_bind()
    assert Dispatcher.get_handler(:test_mode) == self()
    assert Dispatcher.get_handler(:other_mode) == self()
  end

  describe "local" do
    test "dispatching based on registered mode" do
      start_supervised({Receiver, :test_mode})
      assert :ok = Dispatcher.dispatch(:test_mode, :some_message)
    end

    test "dispatching with a default mode" do
      start_supervised({Receiver, :default})
      assert :ok = Dispatcher.dispatch(:test_mode, :some_message)
      assert :ok = Dispatcher.dispatch(:other_mode, :some_message)
    end
  end

  describe "remote" do
    @tag remote: [remote: [{Receiver, :start_link, [:test_mode]}]]
    test "dispatching based on mode", %{remote: remote} do
      assert :ok = Dispatcher.dispatch(remote, :test_mode, :some_message)
    end

    @tag remote: [remote: [{Receiver, :start_link, [:default]}]]
    test "dispatching with a default mode", %{remote: remote} do
      assert :ok = Dispatcher.dispatch(remote, :test_mode, :some_message)
      assert :ok = Dispatcher.dispatch(remote, :other_mode, :some_message)
    end
  end
end
