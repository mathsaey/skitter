# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Invocation do
  @moduledoc """
  Metadata of data being processed.

  It is often necessary to store metadata that belongs to a (set of) tokens. This data is stored
  in the invocation. Strategies have the ability to create new invocations or to add data to an
  invocation.

  This module defines the invocation type and the operations that can be performed on it.
  """

  alias Skitter.Component

  @typedoc """
  Invocation definition.

  An invocation is either a map which stores metadata belonging to a set of tokens or an atom
  which defines that the data associated with this invocation does not store metadata. This can
  occur in two situations:

  - The data is external. This occurs when a source component receives a message that is not
  sent through Skitter. In this case, the invocation is marked as `:external`. The strategy
  handling the message is responsible for creating a proper invocation.

  - The message is a "meta-message". This occurs when strategies wish to propagate information
  through the workflow that is not data to be processed. When this is the case, the message is
  marked as `:meta`.

  Regular invocation contain an `:_id` field, which contains a unique identifer. This can be used
  to differentiate between invocations created at different points in time.
  """
  @type t() :: %{required(:_id) => reference()} | :external | :meta

  @doc "Create a new regular invocation."
  @spec new() :: t()
  def new, do: %{_id: make_ref()}

  @doc "Create a new meta invocation."
  @spec meta() :: t()
  def meta, do: :meta

  @doc """
  Modify the invocation of emitted data.

  This function accepts an enum of data emitted by a component callback and a 0-arity function.
  The function should return an invocation. It will be called once for every emitted element. The
  returned invocation will be used as the invocation for the data element when returned using
  `emit_invocation` inside `c:Skitter.Strategy.Component.process/4`.

  When no function is provided, `new/0` is used, wrapping each element in a new invocation.
  """
  @spec wrap(Component.emit(), (() -> t())) :: Component.emit()
  def wrap(lst, make_inv \\ &new/0) do
    Enum.map(lst, fn {port, enum} ->
      case enum do
        lst when is_list(lst) -> {port, Enum.map(lst, &{&1, make_inv.()})}
        enum -> {port, Stream.map(enum, &{&1, make_inv.()})}
      end
    end)
  end
end
