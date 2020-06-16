# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Runtime do
  @moduledoc """
  """
  alias Skitter.Runtime.{Beacon, Remote}

  defdelegate publish(atom), to: Beacon

  defdelegate accept(remote, mode), to: Remote
  defdelegate connect(remote, mode, server), to: Remote

  defdelegate on_remote(remote, fun), to: Remote, as: :on
  defdelegate on_remote(remote, mod, func, args), to: Remote, as: :on

  defdelegate on_remotes(remotes, fun), to: Remote, as: :on_many
  defdelegate on_remotes(remotes, mod, func, args), to: Remote, as: :on_many
end
