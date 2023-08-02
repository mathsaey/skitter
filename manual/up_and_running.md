# Up and Running

Once [installed](installation.html#skitter), `mix skitter.new <project name>`
can be used to create a new Skitter project. This task creates a new Elixir
project, configures it to use Skitter and provides some initial example code to
help you get started. `<project_name>` should consist of lower case characters,
spaces should be replaced by underscores. The generated project will contain a
`README.md` file with information about the generated code and instructions on
how to run the generated Skitter application. The aforementioned example code
will be present in `lib/<project_name>.ex`.

## Running the project

There are several ways to execute elixir code. The most common way is to use
the following command: `iex -S mix`. This starts the elixir shell (`iex`) and
tells it to start `mix`, which will load your project. To exit `iex`, press
`Ctrl + c` twice.

> #### iex {:.info}
>
> The [official documentation](`IEx`) contains tons of useful information on
> how to use `iex` and on how it can be customized.

If you just want to run your application, you can use `mix run --no-halt`,
which will start your mix project without starting `iex`. `Ctrl + c` can be
used to stop the application, as before.

## Simulating a distributed system

When the mix project is started (using `iex -S mix` or `mix run`), Skitter
automatically starts in its so-called _local_ mode. In this mode, Skitter
acts as both a coordinator and a runner for your distributed stream processing
application, which is useful for development.

If you wish to simulate a distributed system on your local machine, you can
start a skitter master node and one or several skitter worker nodes in
different Elixir runtimes (i.e. in different terminal windows). A master node
can be started by using `mix skitter.master` or `iex -S mix skitter.master`,
while a worker node can be started by using `mix skitter.worker`. Please refer
to the
[deployment documentation](deployment.html#iex-and-mix-during-development)
for more information.
