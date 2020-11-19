# Skitter Core

This library defines the core abstractions offered by the Skitter language. It
is intended to a foundation that can be used by other applications to build a
complete Skitter runtime system.

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
