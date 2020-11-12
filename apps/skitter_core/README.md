# Skitter Core

This library defines the primitives of skitter such as components and
workflows. It is intended as a stable interface that the various other Skitter
applications can use to talk to each other.

## Use

Add the application as a dependency:

```elixir
defp deps do
  [
    {:skitter_core, in_umbrella: true}
  ]
end
```

Once this is done, the various data types (`Skitter.Component`,
`Skitter.Workflow`, `Skitter.Strategy`, …) can be used.
