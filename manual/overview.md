# Overview

Skitter is a distributed stream processing framework written in Elixir which
enables the creation of scalable, distributed stream processing applications.
Unique to Skitter is its ability to control how the various operations which
constitute a stream processing application are distributed at runtime.

These pages serve as the main documentation for Skitter users. They consist of
three main parts, which can be accessed in the top of the sidebar.

* The __manual__: this is the section of the docs you are currently browsing.
  It is a collection of guides which document how to get started with Skitter.
  We recommend first-time users to read through most pages in this manual to
  get up and running with Skitter.

* The __modules__ section: the pages in this section contain the detailed
  documentation of the API offered by Skitter. Various pages in the manual will
  link to the pages in this section of the documentation. We recommend to
  browse these pages on an as-needed basis.


* The __mix tasks__ section: the pages in this section document the mix tasks
  defined by Skitter. `Mix` is the build tool used by Elixir. Mix tasks are
  small command line programs which are used to extend the functionality of
  this tool. We recommend browsing these pages only when needed.

> #### ExDoc Tip {:.tip}
>
> When browsing module or mix task documentation, the "source code" button
> (`</>`) can be used to jump to the source of a documented item on GitHub.

The remainder of this manual is, itself, divided into several parts:

* The __introduction__ pages include this page and the installation
  instructions. They are intended to get you up and running.

* The __concepts__ pages provide an introduction to the various constructs
  which are used to define a Skitter application. These pages are the core part
  of this manual: understanding these concepts is key to reading and writing
  distributed stream processing applications in Skitter.

* The __deployment__ pages document how Skitter applications are deployed over
  a cluster and how they are configured. These pages can be skipped until you
  are ready to run your application in a distributed setting.

* The __guides__ pages document various niche aspects of Skitter. These
  should only need be read when needed.

Throughout this manual, some knowledge of Elixir is assumed. The
[official guide](https://elixir-lang.org/getting-started/introduction.html) and
the [official recommended resources](https://elixir-lang.org/learning.html) are
great places to familiarise yourself with Elixir if needed.
