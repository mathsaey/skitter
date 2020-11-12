# SkitterRemote

This application is used to connect several skitter applications with one
another.

## Use

Add the application as a dependency:

```elixir
def deps do
  [
    {:skitter_remote, in_umbrella: true}
  ]
end
```

In `Application.start/2`, setup the local mode and possible handlers:

```elixir
defmodule Skitter.Worker.Application do
  @moduledoc false

  use Application
  alias Skitter.Remote

  def start(:normal, []) do
    …
    setup_remote()
    …
  end

  defp setup_remote() do
    Remote.set_local_mode(<your mode>)
    Remote.setup_handlers(
      <other mode>: <your handler>,
      default: <your default handler>
    )
  end
end
```

See `Skitter.Remote` for more details about modes and handlers.
