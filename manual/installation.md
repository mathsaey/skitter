# Installation

## Elixir

Skitter is developed as a DSL in [Elixir](https://elixir-lang.org). Therefore,
Elixir is required to write and run Skitter applications. In turn, Elixir is
built upon Erlang/OTP. Therefore, an Erlang/OTP installation is also required.
Skitter requires Elixir version 1.15 or later running on Erlang/OTP version 25
or later.

The [official Elixir documentation](https://elixir-lang.org/install.html)
provides instructions on how to install Elixir (and Erlang/OTP).


## Skitter

We provide an application generator which is used to create a new Skitter
project. This generator creates a new Elixir project, configures it to use
Skitter and provides some initial code to help you get started.

The application generator is provided as a mix task. Mix is an extendable build
tool used by Elixir; it should have been installed together with Elixir.
In order to use the application generator, you need to add it to your local mix
installation, which can be done as follows:

```
$ mix archive.install hex skitter_new
```

Once the task is installed, you can run `mix help skitter.new` to see if
everything is installed correctly. It should produce some text detailing how to
use the task.
