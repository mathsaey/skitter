![skitter logo](https://raw.githubusercontent.com/mathsaey/skitter/develop/assets/logo.png)

A domain specific language for building scalable, reactive workflow applications.
Built in the context of my PhD at the [Software Languages Lab](https://soft.vub.ac.be/).

# Skitter

Skitter is a component agnostic, reactive workflow system; it makes it possible to wrap arbitrary data processing applications into _reactive components_.
These components can be combined into reactive workflows, which can process data entering the system from the outside world.

# Getting Started

To get started with Skitter, you need to have a recent version of [elixir](https://elixir-lang.org/), and [rust](https://www.rust-lang.org/).
Elixir version 1.10 is required. Any recent version of Rust should work.

Once you have Elixir and Rust on your system, you can download the latest version of Skitter and use `mix` to build it:

```
$ git clone https://github.com/mathsaey/skitter.git
$ cd skitter
$ mix deps.get
$ mix build
```

After this is done, the `_build/prod/rel/` directory should contain the skitter runtime applications and the skitter deployment script.
Alternatively, `mix build --path <path>` can be used to save the generated artefacts to another location.
After running `mix build`, elixir and rust may be removed from your system.

In the generated directory, the skitter deployment script, `skitter`, can be used to start and manage a skitter runtime system.
Run `./skitter help` to get started.
