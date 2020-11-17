# SkitterApplication

This application provides some conveniences to create skitter applications.

## Setting up a Skitter Application

The following steps can be used to build an application in this umbrella as a
release:

- Add this application as a dependency:

```elixir
def deps do
  [
    {:skitter_application, in_umbrella: true}
  ]
end
```

- Create a config module:

```elixir
defmodule Skitter.<your application>.Config do
  @moduledoc false
  use Skitter.Application.Config
end
```

- Create a `apps/<your app>/config/release.exs` file.

```elixir
import Skitter.<your application>.Config

<config goes here>
```

- `use Skitter.Application` in your Application module, call
  `noninteractive_skitter_app()` or `interactive_skitter_app()` in
  `Application.start/2`.

```elixir
defmodule Skitter.<your application>.Application do
  @moduledoc false

  use Application
  use Skitter.Application

  def start(:normal, []) do
    interactive_skitter_app()
    …
  end
end
```

- Add the correct entry to the top level `mix.exs` file:

```elixir
defp releases, do: […, release(<your app name>), …]
```

