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
$ MIX_ENV=prod mix build
```

After this is done, the `_build/prod/rel/` directory should contain folders which contain the various skitter applications;
elixir can be safely removed after this step.

Instructions on how to use these applications will be added here later.
Note that Skitter currently does not support windows.
