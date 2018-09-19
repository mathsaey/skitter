defmodule Skitter.Assertions do
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

ExUnit.start()
