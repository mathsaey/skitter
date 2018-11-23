# Copyright 2018, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Test.Assertions do
  import ExUnit.Assertions

  defmacro assert_definition_error(
             msg \\ quote do
               ~r/.*/
             end,
             do: body
           ) do
    quote do
      assert_raise Skitter.DefinitionError, unquote(msg), fn ->
        unquote(body)
      end
    end
  end
end
