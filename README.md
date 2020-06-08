![skitter logo](https://raw.githubusercontent.com/mathsaey/skitter/develop/assets/logo.png)

A domain specific language for building scalable, reactive workflow applications.

# Skitter

Skitter is a component agnostic, reactive workflow system.
It is the main artefact of the PhD I am working on at the [Software Languages Lab](https://soft.vub.ac.be/).

Skitter makes it possible to wrap arbitrary data processing applications into _reactive components_.
These components can be combined into reactive workflows, which can process data entering the system from the outside world.

# Getting Started

To get started with Skitter, you need to have a recent version of [elixir](https://elixir-lang.org/), at the time of writing, Elixir 1.10 is required.
To install elixir, please follow the [official installation instructions](https://elixir-lang.org/install.html).

Once you have a working elixir installation, you can download and build the latest version of skitter:

```
$ git clone https://github.com/mathsaey/skitter.git
$ cd skitter
$ mix build
```

After this is done, the `_build/prod/rel/` directory should contain the skitter runtime applications and the skitter deployment script.
Alternatively, `mix build --path <path>` can be used to save the generated artefacts to another location.
After running `mix build`, elixir may be removed from your system.

In the generated directory, the skitter deployment script, `skitter`, can be used to start and manage a skitter runtime system.
Run `./skitter help` to get started.
