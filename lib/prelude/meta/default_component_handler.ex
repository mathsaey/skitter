# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Prelude.Meta.DefaultComponentHandler do
  @moduledoc """
  Default component handler.

  This component handler is automatically used when a component does not
  explicitly specify a handler
  (as documented in `Skitter.Component.defcomponent/3`).

  # TODO: Document requirements and behaviour.
  """
  @behaviour Skitter.Prelude

  @impl true
  def _load do
    import Skitter.Component.Handler

    defhandler DefaultComponentHandler do
      on_define c do
        c
        |> default_callback(:init, defcallback([], [], [], do: nil))
        |> default_callback(:terminate, defcallback([], [], [], do: nil))
        |> require_callback(:init, state_capability: :readwrite)
        |> require_callback(:terminate, state_capability: :read)
        |> require_callback(:react,
          arity: length(c.in_ports),
          state_capability: :read,
          publish_capability: true
        )
        ~> component
      end

      on_embed comp, args do
        require_instantiation_arity(comp, args, comp.callbacks.init.arity)
        comp ~> component
        args ~> arguments
      end
    end
  end
end
