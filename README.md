![skitter logo](https://raw.githubusercontent.com/mathsaey/skitter/develop/assets/logo.png)

A domain specific language for building horizontally scalable, reactive workflow applications.
Built in the context of my PhD at the [Software Languages Lab](https://soft.vub.ac.be/).

# Skitter

Skitter is a component agnostic, reactive workflow system; it makes it possible to wrap arbitrary data processing applications into _reactive components_.
These components can be combined into reactive workflows, which can be deployed over a cluster.
Once deployed, a reactive workflow can process data entering the system from the outside world.

In order to support the distribution of arbitrary components over a cluster, Skitter components define a _strategy_: a meta-level language construct which defines how components are distributed over a cluster.
Through the use of these strategies, a programmer writing a Skitter application can select the most appropriate distribution strategy based on the exact properties of the reactive component.

## Status

__This version of skitter is a work in progress. It is currently not usable.__
The earlier, effect based, version of Skitter can be found [here](https://github.com/mathsaey/skitter/releases/tag/v0.1).

## Getting Started

To get started with Skitter, you need to have a recent version of [elixir](https://elixir-lang.org/).
Currently, elixir version 1.10 is supported.

Once Elixir is installed, you can download the latest version of Skitter and use `mix` to build it:

```
$ git clone https://github.com/mathsaey/skitter.git
$ cd skitter
$ mix deps.get
$ mix build
```

After this is done, the `_build/prod/rel/` directory should contain the skitter runtime applications and the skitter deployment script.
Alternatively, `mix build --path <path>` can be used to save the generated artefacts to another location.
After running `mix build`, elixir may be removed from your system.

In the generated directory, the skitter deployment script, `skitter`, can be used to start and manage a skitter runtime system.
Run `./skitter help` to get started.
