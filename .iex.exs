# Common imports
import Skitter.Component

# Debugging tools
defmodule SkDebug do
  defp expand_n_times(body, n), do: expand_n_times(body, n, 0)
  defp expand_n_times(body, n, n), do: body
  defp expand_n_times(body, n, x) do
    expand_n_times(Macro.expand_once(body, __ENV__), n, x + 1)
  end

  defmacro test_macro(times \\ 1, do: body) do
    body |> expand_n_times(times) |> Macro.to_string |> IO.puts
  end
end

