# Skitter Dot

This library makes it possible to export skitter workflows as graphviz dot
graphs.

## Use

Add the application as a dependency:

```elixir
defp deps do
  [
    {:skitter_dot, in_umbrella: true}
  ]
end
```

After, the functions in `Skitter.Dot` can be used to generate a dot
representation of a given workflow.
