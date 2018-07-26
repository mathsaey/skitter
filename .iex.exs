# Common imports
import Skitter.Component

component Average, in: val, out: current_average do
  fields total, counter
  effect state_change

  init _ do
    total <~ 0
    counter <~ 0
  end

  react val do
    total <~ total + val
    counter <~ counter + 1

    total / counter ~> current_average
  end
end

# Debugging tools
defmodule SkDebug do
  # Expand everything we encounter except `defmodule`, `def`, and `defp`
  defp expand_custom(ast = {:def, _env, _args}), do: ast
  defp expand_custom(ast = {:defp, _env, _args}), do: ast
  defp expand_custom(ast = {:defmodule, _env, _args}), do: ast

  defp expand_custom(other) do
    Macro.expand_once(other, __ENV__)
  end

  # Expand every macro in the AST
  defp expand_ast(ast), do: Macro.prewalk(ast, &expand_custom/1)

  # Recursively expand macros, n times
  defp expand_n_times(b, n), do: expand_n_times(b, n, 0)

  # Helper for `expand_n_times/2`
  defp expand_n_times(b, n, n), do: b
  defp expand_n_times(b, n, x), do: expand_n_times(expand_ast(b), n, x + 1)

  defmacro test_macro(times \\ 1, do: body) do
    body |> expand_n_times(times) |> Macro.to_string() |> IO.puts()
  end
end
