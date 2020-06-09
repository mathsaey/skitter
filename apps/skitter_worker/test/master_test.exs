# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Worker.MasterTest do
  use Skitter.Runtime.Test.ClusterCase, async: false
  import ExUnit.CaptureLog

  alias Skitter.Worker.Test.DummyMaster

  alias Skitter.Runtime
  alias Skitter.Worker.Master
  alias Skitter.Worker.Application.Supervisor, as: ApplicationSupervisor

  setup do
    Supervisor.terminate_child(ApplicationSupervisor, Master)
    Supervisor.restart_child(ApplicationSupervisor, Master)
    :ok
  end

  describe "connecting" do
    test "discovery errors are propagated" do
      assert Master.connect(:"test@127.0.0.1") == {:error, :not_distributed}
    end

    @tag distributed: [remote: [{Runtime, :publish, [:not_a_master]}]]
    test "to a non-master fails", %{remote: remote} do
      assert Master.connect(remote) == {:error, :not_master}
    end

    @tag distributed: [master: [{DummyMaster, :start, [false]}]]
    test "can be rejected", %{master: master} do
      assert Master.connect(master) == {:error, :rejected}
    end

    @tag distributed: [master: [{DummyMaster, :start, [true]}]]
    test "successfully", %{master: master} do
      assert Master.connect(master) == :ok
    end

    @tag distributed: [
           first: [{DummyMaster, :start, [true]}],
           second: [{DummyMaster, :start, [true]}]
         ]
    test "twice is not possible", %{first: first, second: second} do
      assert Master.connect(first) == :ok
      assert Master.connect(second) == {:error, :already_connected}
    end

    @tag distributed: [master: [{DummyMaster, :start, [true]}]]
    test "detects master failure", %{master: master} do
      assert Master.connect(master) == :ok

      assert capture_log(fn ->
               Cluster.kill_node(master)
               # Wait for handle_info to finish
               :sys.get_state(Master)
             end) =~ "Master `#{master}` disconnected"

      assert :sys.get_state(Master) == nil
    end
  end

  describe "accepting" do
    @tag distributed: [remote: [{Runtime, :publish, [:not_a_master]}]]
    test "only accepts masters", %{remote: remote} do
      assert :sys.get_state(Master) == nil
      assert not Cluster.rpc(remote, GenServer, :call, [{Master, Node.self()}, {:accept, remote}])
      assert :sys.get_state(Master) == nil
    end

    @tag distributed: [master: [{Runtime, :publish, [:skitter_master]}]]
    test "successfully", %{master: master} do
      assert Cluster.rpc(master, GenServer, :call, [{Master, Node.self()}, {:accept, master}])
      assert :sys.get_state(Master) == master
    end

    @tag distributed: [
           first: [{Runtime, :publish, [:skitter_master]}],
           second: [{Runtime, :publish, [:skitter_master]}]
         ]
    test "twice is not possible", %{first: first, second: second} do
      assert Cluster.rpc(first, GenServer, :call, [{Master, Node.self()}, {:accept, first}])
      assert not Cluster.rpc(second, GenServer, :call, [{Master, Node.self()}, {:accept, second}])
      assert :sys.get_state(Master) == first
    end

    @tag distributed: [master: [{Runtime, :publish, [:skitter_master]}]]
    test "detects master failure", %{master: master} do
      assert Cluster.rpc(master, GenServer, :call, [{Master, Node.self()}, {:accept, master}])
      assert :sys.get_state(Master) == master

      assert capture_log(fn ->
               Cluster.kill_node(master)
               # Wait for handle_info to finish
               :sys.get_state(Master)
             end) =~ "Master `#{master}` disconnected"

      assert :sys.get_state(Master) == nil
    end
  end
end
