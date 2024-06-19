# Overview

Skitter is a distributed stream processing framework. The idea behind these
frameworks is to process various _streams_ of incoming data. Distributed stream
processing frameworks are designed to process large volumes of data. This is
done by _distributing_ the processing of these streams over different computers.

Similar to other distributed stream processing frameworks, Skitter offers a
programming model where streams of data are processed through various
**operations**. An operation is connected to several streams and is responsible
for processing data that arrives on these streams. The operation may also emit
data on streams, which can then be processed by other operations in the
application.

![](assets/docs/operations.svg)

Operations which do not receive input and only produce values are called
*sources*, while operations which receive input and do not produce any output
are called *sinks*.

A Skitter application is created by combining several of
these operations into a **workflow**.

![](assets/docs/workflow.svg)

Once created, a Skitter workflow can be distributed over a cluster (i.e. over a
collection of different computers), after which it can start to process
incoming data records.

Existing distributed stream processing frameworks automatically distribute a
stream processing application over a cluster. Unique to Skitter is its support
for specifying how each operation in a stream processing application is
distributed. This is done by writing a **distribution strategy**.

## Three languages

Therefore, Skitter introduces three languages:

- The **workflow** language is used to combine several existing operations into
  a workflow.
- The **operation** language is used to create new operations which can be used
  in these workflows.
- The **strategy** language is used to define how operations can be distributed
  over a cluster.

Each of these languages is introduced in detail in the following pages of this
manual.
