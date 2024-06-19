# Workflows

Skitter applications are defined as the combination of several data processing
steps connected to one another. We call such a combination of connected data
processing steps a _workflow_.

Each data processing step is defined as an _operation_, which we discuss in the
next section of this guide. For now, it suffices to think of these operations
as black boxes which ingest data, potentially emitting new data as they do so.
An operation receives data on its input _ports_ and emits data using its output
ports. A workflow combines several of these operations by connecting the out
ports of operations to the in ports of other operations.

As an example, let's define the "Hello, World!" application of stream
processing frameworks: a word count:

![a schematic depiction of a word count application consisting of two nodes: split and count](assets/docs/word_count_schematic.svg)

This workflow consists of four operations: source, split and print:
- The source operation produces the sentences of which the words will be
  counted.
- The split operation accepts sentences and splits them, emitting individual
  words.
- The count operation accepts words and returns `(word, count)` pairs, which
  specify how many times `word` has been seen thus far.
- The print operation accepts the count pairs and shows them to the user.

Let's assume that we have defined a Skitter operation for each of these steps,
called `Source`, `Split`, `Count` and `Print`. We can now define the word count
application as a Skitter workflow:

```
use Skitter

word_count = workflow do
  node(Source, as: source)
  node(Split, as: split)
  node(Count, as: count)
  node(Print, as: print)

  source.out ~> split.sentences
  split.words ~> count.words
  count.pairs ~> print.pairs
end
```

The above code uses `Skitter.DSL.Workflow.workflow/2` to define a workflow. A
workflow is defined by combining several _nodes_, each of which "wrap" an
operation, and by "wiring" these nodes together through the use of _links_.
Nodes are created with the use of the `Skitter.DSL.Workflow.node/2` macro,
while links are introduced through the use of `Skitter.DSL.Workflow.~>/2`.

Visually, this workflow can be represented as follows:

![Graphical representation of the workflow shown above](assets/docs/word_count.svg)

> #### Visualising workflows {:.tip}
>
> Skitter workflows can be visualised through the use of the functions defined
> in `Skitter.Dot`. The visual representations of workflows shown in this
> document were generated through the use of this tool.

## Nodes

Nodes in a workflow represent a single data processing step. They typically
refer to an operation, which implements the data processing logic of the node,
and to a strategy, which determines how the operation is distributed over the
cluster. A node also has a name, which is used to refer to the node when
creating links. Nodes may also accept arguments, which can be used to provide
initialization arguments to the strategy or operation of the node.

When a node is created, an operation must be provided, the name, strategy and
arguments of the node may be provided, through the use of `as:`, `with:`, and
`args:`, respectively.

```
node(SomeOperation, with: someStrategy, args: [some_argument], as: name)
```

When no name is provided, the workflow language will generate a unique name.
If no strategy is present, the _default strategy_ of the operation will be
used. Arguments default to `nil` when not provided.

## Links and syntactic sugar

Links in a workflow connect a particular output of a node with the input of
another node.

```
operation.out_port ~> other_operation.in_port
```

The link operator, `Skitter.DSL.Workflow.~>/2`, introduces syntactic sugar to
make workflow definitions more concise. When the left-hand side of `~>`
operator contains a node definition, the first output port of this node will be
connected to the right-hand side of the link. Similarly, when the right-hand
side of `~>` contains a node definition, the left-hand side of the link will be
connected to the first input of this node. This allows node definitions in a
workflow to be chained:

```
use Skitter

word_count = workflow do
  node(Source)
  ~> node(Split)
  ~> node(Count)
  ~> node(Print)
end
```

![Graphical representation of the workflow shown above (it remains largely unchanged)](assets/docs/word_count_chained.svg)

## Operator-style workflow definitions

Many distributed stream-processing frameworks offer a programming model where
applications are created by chaining various _operators_, such as `map` and
`reduce`. This can also be done in Skitter:

```
use Skitter

word_count = workflow do
  stream_source(~w(Hello Skitter Hello World!))
  ~> flat_map(&String.split/1)
  ~> keyed_reduce(fn word -> word end, fn word, ctr -> {ctr + 1, {word, ctr + 1}} end, 0)
  ~> print()
end
```

![Graphical representation of the operator-style workflow definition](assets/docs/word_count_operators.svg)

This is possible because Skitter predefines various operations, called
_built-in operations_, BIO for short. The full list of BIOs can be found in the
modules section of the documentation. In the example above, the following BIOs
are used:

- `Skitter.BIO.StreamSource`
- `Skitter.BIO.FlatMap`
- `Skitter.BIO.KeyedReduce`
- `Skitter.BIO.Print`

These BIOs can be used in a workflow like regular nodes:

```
use Skitter

word_count = workflow do
  node(Skitter.BIO.StreamSource, args: ~w(Hello Skitter Hello World!))
  ~> node(Skitter.BIO.FlatMap, args: &String.split/1)
  ~> node(Skitter.BIO.KeyedReduce, args: {fn word -> word end, fn word, ctr -> {ctr + 1, {word, ctr + 1}} end, 0})
  ~> node(Skitter.BIO.Print)
end
```

However, the `Skitter.BIO` module defines various macros which can be used to
define these nodes, as shown earlier in this section. The full list of these
macros is defined in `Skitter.BIO`. Since Skitter is extensible, you are able
to add your own operators to Skitter. How this is done is defined in the
[operators guide](operators.md).

## Nested workflows

Finally, workflows can be stored as values and used inside nodes. This makes it
possible to reuse workflows:

```
use Skitter

defmodule Example do
  def listen_and_preprocess(port) do
    workflow out: integers do
      tcp_source("127.0.0.1", port) ~> map(&String.to_integer/1) ~> integers
    end
  end

  def workflow do
    workflow do
      node(listen_and_preprocess(5555), as: top) ~> join.left
      node(listen_and_preprocess(5556), as: bottom) ~> join.right

      node(Join, as: join)
      ~> print()
    end
  end
end
```

`Example.workflow()` will return the following workflow:

![Graphical representation of the nested workflows](assets/docs/workflow_nested.svg)

Nested workflows are always inlined before a workflow is deployed over the
cluster.

![Graphical representation of the nested workflows after inlining](assets/docs/workflow_flatenned.svg)
