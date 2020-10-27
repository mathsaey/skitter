# Skitter DSL

This application defines several macros which can be used to write skitter
applications within Elixir.
Each of these macros compiles down to a datatype defined in `:skitter_core`.

## Use

Add the application as a dependency:

```elixir
defp deps do
  [
    {:skitter_dsl, in_umbrella: true}
  ]
end
```

Afterwards, `Skitter.DSL` can be used to import all the Skitter DSLs:

```
use Skitter.DSL
```

