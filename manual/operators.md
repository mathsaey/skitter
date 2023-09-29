# Operators

Many stream processing frameworks (e.g. Spark, Flink, …) use an operator-based
programming model where applications are expressed by chaining calls to
well-known operations such as `map`, `join`, `reduce`, and others. In Skitter,
however, applications are expressed by combining operations defined elsewhere.

Nevertheless, the well-known operations described above can easily be
implemented in Skitter. Skitter provides the following operations out of the box:

* `Skitter.BIO.Filter`
* `Skitter.BIO.FlatMap`
* `Skitter.BIO.KeyedReduce`
* `Skitter.BIO.Map`
* `Skitter.BIO.MessageSource`
* `Skitter.BIO.Print`
* `Skitter.BIO.Send`
* `Skitter.BIO.StreamSource`
* `Skitter.BIO.TCPSource`

These operations can be used in a workflow definition:
```
workflow do
  node(Skitter.BIO.StreamSource, args: ~w(Hello Skitter Hello World!))
  ~> node(Skitter.BIO.FlatMap, args: &String.split/1)
  ~> node(Skitter.BIO.KeyedReduce, args: {
    fn word -> word end,
    fn word, ctr -> {ctr + 1, {word, ctr + 1}} end,
    0
  })
  ~> node(Skitter.BIO.Print)
end
```
However, it quickly becomes tedious to write applications like this. Therefore,
the `Skitter.BIO` module defines several macros which provide shorthands for
using these built-in operations. The
[Skitter workflow DSL](`Skitter.DSL.Workflow.workflow/2`) imports these
shorthands implicitly. Thus the application above can be written as follows:
```
workflow do
  stream_source(~w(Hello Skitter Hello World!))
  ~> flat_map(&String.split/1)
  ~> keyed_reduce(fn word -> word end, fn word, ctr -> {ctr + 1, {word, ctr + 1}} end, 0)
  ~> print()
end
```
In Skitter, these macros are called _operators_.

## Defining Custom Operators

It is possible to define your own operators which can then be imported into the
workflow DSL.

For instance, `Skitter.BIO.map/2` is defined as follows:

```
defmacro map(func, opts \\ []) do
  opts = [args: func] ++ opts
  quote(do: node(Skitter.BIO.Map, unquote(opts)))
end
```

This macro accepts two arguments: the function which will be mapped over the
incoming data and any other options (i.e. the `as:` and `with:` options
accepted by `Skitter.DSL.Workflow.node/2`). Based on these, it creates a call
to `Skitter.DSL.Workflow.node/2`, with the function argument merged into the
node's option list. This call to `node` must be quoted, as it will be inserted
into the workflow DSL.

Thus, an operator definition must do the following:
- It must be defined as a macro.
- It must return a quoted call to `Skitter.DSL.Workflow.node/2`.
- It must accept optional options, which are passed as the second argument to
  `Skitter.DSL.Workflow.node/2`.

Operators defined this way can then be imported into the workflow DSL using
`import/2`.

To wrap up, let's show a complete example of defining and using a custom
operator. We will define an operator which uses `Skitter.BIO.FlatMap` and embed
it in the workflow shown above.

First, we define the operator in a module:

```
defmodule MyCustomOperators do
  defmacro my_flat_map(func, opts \\ []) do
    quote(do: node(Skitter.BIO.FlatMap, unquote([args: func] ++ opts)))
  end
end
```

After, we define a workflow importing the module after which we can use the
operator:

```
workflow do
  import MyCustomOperators

  stream_source(~w(Hello Skitter Hello World!))
  ~> my_flat_map(&String.split/1)
  ~> keyed_reduce(fn word -> word end, fn word, ctr -> {ctr + 1, {word, ctr + 1}} end, 0)
  ~> print()
end
```
