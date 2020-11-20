# SkitterApplication

This application provides some conveniences to create skitter applications.

## Setting up a Skitter Application

The following steps can be used to build an application in this umbrella which
can be built as a release:

- Mark this application as a release in the application `mix.exs` and add this
  application as a dependency:

```elixir
def project do
  Setup.rel(
    :skitter_<name>,
    deps: deps(),
    ...
  )
end

def deps do
  [
    {:skitter_application, in_umbrella: true}
  ]
end
```

- Create a `apps/<your app>/config/release.exs` file which will be used to
  configure your release at runtime:

```elixir
import Skitter.Application.Config

<config goes here>
```

- Create a `apps/<your app>/config/config.exs` file for build-time configuration
  if needed:

```elixir
import Config

import_config "../../../config/config.exs"

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
