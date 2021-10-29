# Copyright 2018 - 2021, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Component, only: :macros

defcomponent Skitter.BIC.MessageSource, out: _, strategy: Skitter.BIS.PassiveSource do
  @componentdoc """
  Development source which can receive messages from elixir processes.

  This component is a source which can receive data from Elixir messages. It should be created
  with a _tag_ which is used to message the source later. After the component is deployed,
  `send/2` can be used to send a message to a source with a given tag.

  This component is only intended to be used locally. It does not work in a distributed
  environment.
  """
  defcb subscribe(tag), do: :persistent_term.put({__MODULE__, tag}, self())
  defcb process(msg), do: msg ~> _

  @doc """
  Send a message to a `messagesource` tagged with `tag`.
  """
  def send(tag, msg) do
    case :persistent_term.get({__MODULE__, tag}, nil) do
      nil ->
        {:error, :missing_tag}

      pid ->
        Kernel.send(pid, msg)
        :ok
    end
  end
end
