# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Operation, only: :macros

defoperation Skitter.BIO.MessageSource, out: _, strategy: Skitter.BIS.PassiveSource do
  @operationdoc """
  Development source which can receive messages from elixir processes.

  This operation is a source which can receive data from Elixir messages. After the operation is
  deployed, `send/2` can be used to send a message to the source. Only one message source can
  exist at the same time.

  This operation is only intended to be used locally. It does not work in a distributed
  environment.
  """
  defcb subscribe(_), do: :persistent_term.put(__MODULE__, self())
  defcb process(msg), do: msg ~> _

  @doc """
  Send a message to the message source.
  """
  def send(msg) do
    __MODULE__ |> :persistent_term.get() |> Kernel.send(msg)
  end
end
