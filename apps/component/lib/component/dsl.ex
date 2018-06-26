defmodule Skitter.Component.DSL do
  @moduledoc """
  DSL to define skitter components.

  This module offers a DSL to implement components. The entry point of this DSL
  is the `component/3` macro.  Besides this, this module offers a set of macros
  which can be used inside the body of `component/3`.  These macros cannot be
  used outside `component/3`, as they rely on AST transformations to work.

  A component consists of a collection of metadata alongside the implementation
  of a set of functions. Metadata is provided in both the _header_ of the
  component and in its body. Functions are implemented inside the component
  body. When writing a component, a `react/3` function has to be implemented.
  Besides this, `init/3` and `terminate/3` can always be implemented (though
  this is not required), `create_checkpoint/3`, `restore_checkpoint/3` have to
  be implemented if certain _effects_ are present, `clean_checkpoint/3` may be
  implemented when these effects are present, but this is not required.

  A component which stores a running average is provided here as an example:

  ```
  component Average, in: value, out: average do
    "Track the average of all received values"

    effect state_change
    fields total, counter

    init _ do
      total <~ 0
      counter <~ 0
    end

    react value do
      total <~ total + value
      counter <~ counter + 1

      total / counter ~> average
    end
  end
  ```

  ## Metadata

  The following metadata can be provided when defining a component:

  Name | Required? | Location | Syntax
  ---- | --------- | -------- | ------
  _in_ports_    | always | header | `in: [port, another_port]`
  _out_ports_   | no     | header | `out: [port, another_port]`
  _description_ | no     | body   | `"documentation goes here"`
  _effects_     | no     | body   | `effect effect_name property`

  Ports define how a component can interact with a workflow.
  _in_ ports provide a way for the component to _receive_ values.
  A component instance automatically _reacts_ to data when it has an input
  value on each of its input ports. _out_ ports allow a component to publish
  data while _reacting_ to incoming data. Any data published on an out port will
  automatically be forwarded to any component instance which is connected to
  this out port. A component must always specify its in ports, out ports do not
  need to be specified in which case the component cannot publish any data.
  As a syntactic convenience, a component can leave out the list notation when
  only one port is present, e.g. `in: foo, out: bar` is automatically
  transformed into `in: [foo], out: [bar]`

  A description can be provided as the first line of a component. It simply
  serves as documentation for the component.

  Effects modify how the skitter runtime will handle the execution of a
  component. Currently, skitter supports the following effects:

  | Name              | Properties |
  | ----------------- | ---------- |
  | _state_change_    | _hidden_   |
  | _external_effect_ |            |
  """

  import Skitter.Component.DefinitionError

  # --------- #
  # Constants #
  # --------- #

  # Effects which are accepted by skitter + their properties
  @valid_effects [state_change: [:hidden], external_effect: []]

  # Functions components can implement
  @component_functions [
    :react,
    :init,
    :terminate,
    :restore_checkpoint,
    :clean_checkpoint,
    :create_checkpoint
  ]

  # Functions for which a default is generated
  @default_callbacks List.delete(@component_functions, :react)

  # Names of skitter variables which are injected into the user code
  @output_var :output
  @instance_var :instance

  # --------- #
  # Component #
  # --------- #

  @doc """
  Create a skitter component.

  This macro serves as the entry point of the component DSL.
  """
  defmacro component(name, ports, do: body) do
    # Get metadata from header
    full_name = module_name_to_snake_case(Macro.expand(name, __CALLER__))
    {in_ports, out_ports} = read_ports(ports)

    # Extract metadata from body AST
    {body, desc} = extract_description(body)
    {body, fields} = extract_fields(body)
    {body, effects} = extract_effects(body)

    # Generate moduledoc based on description
    moduledoc = generate_moduledoc(desc)

    # Gather metadata
    internal_metadata = %{
      name: full_name,
      description: desc,
      fields: fields,
      effects: effects,
      in_ports: in_ports,
      out_ports: out_ports
    }

    # Create metadata struct
    component_metadata = struct(Skitter.Component.Metadata, internal_metadata)

    # Transform macro calls inside body AST
    # body = transform_component_callbacks(body, internal_metadata)
    body = body |> transform_helpers() |> transform_functions(internal_metadata)

    # Add default callbacks
    defaults = generate_default_callbacks(body, internal_metadata)

    # Check for errors
    errors = check_component_body(body, internal_metadata)

    quote generated: true do
      defmodule unquote(name) do
        @behaviour unquote(Skitter.Component.Behaviour)
        @moduledoc unquote(moduledoc)

        import unquote(Skitter.Component), only: []

        import unquote(__MODULE__),
          only: [
            react: 3,
            init: 3,
            terminate: 3,
            create_checkpoint: 3,
            restore_checkpoint: 3,
            clean_checkpoint: 3
          ]

        unquote(errors)
        defstruct unquote(fields)

        unquote(body)
        unquote(defaults)

        def __skitter_metadata__, do: unquote(Macro.escape(component_metadata))
      end
    end
  end

  # Transformation / Data extraction
  # --------------------------------

  # Generate a readable string (i.e. a string with spaces) based on the name
  # of a component.
  defp module_name_to_snake_case(name) do
    name = name |> Atom.to_string() |> String.split(".") |> Enum.at(-1)
    rgxp = ~r/([[:upper:]]+(?=[[:upper:]]|$)|[[:upper:]][[:lower:]]*|\d+)/
    rgxp |> Regex.replace(name, " \\0") |> String.trim()
  end

  # Make it possible to not specify the out ports when there are none
  defp read_ports(in: in_ports), do: read_ports(in: in_ports, out: [])

  defp read_ports(in: in_ports, out: out_ports) do
    {parse_port_names(in_ports), parse_port_names(out_ports)}
  end

  defp parse_port_names(lst) when is_list(lst) do
    Enum.map(lst, &name_to_symbol/1)
  end

  # Allow a single port name to be specified outside a list
  defp parse_port_names(el), do: parse_port_names([el])

  # Retrieve the description from a component if it is present.
  # A description is provided when the component body start with a string.
  # Remove the string from the component body and return it as the description.
  defp extract_description({:__block__, env, [str | r]}) when is_binary(str) do
    {{:__block__, env, r}, str}
  end

  defp extract_description(str) when is_binary(str) do
    {quote generated: true do
     end, str}
  end

  defp extract_description(any), do: {any, ""}

  # Find and remove field declarations in the AST
  defp extract_fields(body) do
    Macro.postwalk(body, [], fn
      {:fields, _env, fields}, [] ->
        fields =
          Enum.map(fields, fn
            {name, _env, atom} when is_atom(atom) -> name
            any -> {:error, any}
          end)

        {nil, fields}

      {:fields, _env, _args}, _fields ->
        {nil, :error}

      any, acc ->
        {any, acc}
    end)
  end

  # Extract effect declarations from the AST and add the effects to the effect
  # list.
  # Effects are specified as either:
  #  effect effect_name property1, property2
  #  effect effect_name
  # In both cases, the full statement will be removed from the ast, and the
  # effect will be added to the accumulator with its properties.
  defp extract_effects(body) do
    Macro.postwalk(body, [], fn
      {:effect, _env, [effect]}, acc ->
        {effect, properties} = Macro.decompose_call(effect)

        properties =
          Enum.map(properties, fn
            {name, _env, _args} -> name
            any -> {:error, any}
          end)

        {nil, Keyword.put(acc, effect, properties)}

      any, acc ->
        {any, acc}
    end)
  end

  # If no description is provided, set moduledoc to false
  defp generate_moduledoc(""), do: false

  # Otherwise add some additional information to the moduledoc
  defp generate_moduledoc(desc) do
    """
      #{desc}

      _This moduledoc of this component was automatically generated by_
      _`Skitter.Component.DSL`_.
    """
  end

  # helper functions are defined as internal functions
  defp transform_helpers(body) do
    Macro.postwalk(body, fn
      {:helper, env, rest} ->
        {:defp, env, rest}

      any ->
        any
    end)
  end

  # Modify the calls to the macros which define the component functions.
  # Wrap their arguments in a list (to allow an arbitrary amount of arguments
  # when needed), and add the component metadata to the call.
  defp transform_functions(body, meta) do
    Macro.postwalk(body, fn
      {name, env, arg_lst} when name in @component_functions ->
        {args, [block]} = Enum.split(arg_lst, -1)
        {name, env, [args, meta, block]}

      any ->
        any
    end)
  end

  # Error Checking
  # --------------

  defp check_component_body(body, meta) do
    [
      check_fields(meta),
      check_effects(meta),
      check_react(body, meta),
      check_checkpoint(body, meta),
      check_port_names(meta.in_ports),
      check_port_names(meta.out_ports)
    ]
  end

  # Ensure all ports are valid.
  # Errors are already flagged by the port names parser, just extract them here.
  defp check_port_names(list) do
    case Enum.find(list, &match?({:error, _}, &1)) do
      {:error, val} ->
        inject_error "`#{val}` is not a valid port"

      nil ->
        nil
    end
  end

  # Check if the specified effects are valid.
  # If they are, ensure their properties are valid as well.
  defp check_effects(metadata) do
    for {effect, properties} <- metadata.effects do
      with valid when valid != nil <- Keyword.get(@valid_effects, effect),
           [] <- Enum.reject(properties, fn p -> p in valid end) do
        nil
      else
        nil ->
          inject_error "Effect `#{effect}` is not valid"

        [{:error, prop} | _] ->
          inject_error "`#{prop}` is not a valid property"

        [prop | _] ->
          inject_error "`#{prop}` is not a valid property of `#{effect}`"
      end
    end
  end

  # Handle the errors returned by `extract_fields/1`
  defp check_fields(metadata) do
    case metadata.fields do
      nil ->
        nil

      :error ->
        inject_error "Fields can only be defined once."

      lst when is_list(lst) ->
        Enum.map(lst, fn
          {:error, any} -> inject_error "`#{any}` is not a valid field"
          _ -> nil
        end)
    end
  end

  # Ensure react is present in the component
  defp check_react(body, meta) do
    unless_occurrence(body, :react) do
      inject_error "Component `#{meta.name}` lacks a react implementation"
    end
  end

  # Ensure checkpoint and restore are present if the component manages its own
  # internal state. If it does not, ensure they are not present.
  defp check_checkpoint(body, meta) do
    required = :hidden in Keyword.get(meta.effects, :state_change, [])
    cp_present = count_occurrences(body, :create_checkpoint) >= 1
    rt_present = count_occurrences(body, :restore_checkpoint) >= 1
    cl_present = count_occurrences(body, :clean_checkpoint) >= 1
    either_present = cp_present or rt_present or cl_present
    both_present = cp_present and rt_present

    case {required, either_present, both_present} do
      {true, _, true} ->
        nil

      {false, false, _} ->
        nil

      {true, _, false} ->
        inject_error "`create_checkpoint` and `restore_checkpoint` are " <>
                       "required when the state change is hidden"

      {false, true, _} ->
        inject_error "`create_checkpoint`, `restore_checkpoint` and " <>
                       "`clean_checkpoint` are only allowed when the state " <>
                       "change is hidden"
    end
  end

  # Default Generation
  # ------------------

  # Default implementations of various skitter functions
  # We cannot use defoverridable, as the compiler will remove it before
  # the init, react, ... macros are expanded.
  defp generate_default_callbacks(body, meta) do
    defaults = %{
      init: &default_init/1,
      terminate: &default_terminate/1,
      create_checkpoint: &default_create_checkpoint/1,
      restore_checkpoint: &default_restore_checkpoint/1,
      clean_checkpoint: &defaul_clean_checkpoint/1
    }

    Enum.map(@default_callbacks, fn name ->
      unless_occurrence(body, name, do: defaults[name].(meta))
    end)
  end

  defp default_init(_) do
    quote generated: true do
      def __skitter_init__(_) do
        {:ok, unquote(create_instance())}
      end
    end
  end

  defp default_terminate(_) do
    quote generated: true do
      def __skitter_terminate__(_), do: :ok
    end
  end

  defp default_create_checkpoint(_) do
    quote generated: true do
      def __skitter_create_checkpoint__(_), do: :nocheckpoint
    end
  end

  defp default_restore_checkpoint(_) do
    quote generated: true do
      def __skitter_restore_checkpoint__(_), do: :nocheckpoint
    end
  end

  defp defaul_clean_checkpoint(meta) do
    required = :hidden in Keyword.get(meta.effects, :state_change, [])
    res = if required, do: :ok, else: :nocheckpoint

    quote generated: true do
      def __skitter_clean_checkpoint__(_i, _c), do: unquote(res)
    end
  end

  # ----- #
  # React #
  # ----- #

  @doc """
  React to incoming data.

  React to incoming data from the in ports. Every in port of the component
  should have a matching parameter in the "header" of react.
  For instance, if a component has two in ports: `foo`, and `bar`, the
  react of that component should start as follows: `react foo, bar do ...`
  The names of the parameters can be freely chosen and pattern matching is
  possible. Elixir guards cannot be used.
  """
  defmacro react(args, meta, do: body) do
    body = transform_field_access(body, meta)

    errors = check_react_body(args, meta, body)

    react_body = remove_after_failure(body)
    failure_body = build_react_after_failure_body(body, meta)

    {react_body, react_arg} = create_react_body_and_arg(react_body)
    {fail_body, fail_arg} = create_react_body_and_arg(failure_body)

    quote generated: true do
      unquote(errors)

      def __skitter_react__(unquote(react_arg), unquote(args)) do
        unquote(react_body)
      end

      def __skitter_react_after_failure__(unquote(fail_arg), unquote(args)) do
        unquote(fail_body)
      end
    end
  end

  @doc """
  Provide a value to the workflow on a given port.

  The given value will be sent to every other component that is connected to
  the provided output port of the component.
  The value will be sent _after_ `react/3` has finished executing.

  Usable inside `react/3` iff the component has at least one output port.
  """
  defmacro value ~> port do
    port = name_to_symbol(port)
    var = skitter_var(@output_var)

    quote generated: true do
      unquote(var) = Keyword.put(unquote(var), unquote(port), unquote(value))
    end
  end

  @doc """
  Code that should only be executed after a failure occurred.

  _Usable inside `react/3` iff the component has an external state._

  The code in this block will only be executed if `react/3` is triggered
  after a failure occurred. Otherwise, the code in this block will be ignored.

  This block is mainly meant to provide clean up code in case a component
  experiences some form of failure. For instance, if a call to react can
  produce some side effect, this block can check if that side effect already
  occurred before deciding whether or not execution should proceed.

  ## Example

  For instance, let's look at the following react function, which writes a
  value to some database after which it sends it to an output port.

  ```
  react val do
    write_to_db(val)
    val ~> port
  end
  ```

  The skitter runtime would have no way of knowing whether or not the database
  was updated if this component would fail in the middle of a call to `react`.
  However, in order to ensure the remainder of the workflow is still activated
  correctly, the value sent to `port` is needed.

  To solve this problem, we can use the `after_failure` block:

  ```
  react val do
    after_failure do
      if write_to_db_occurred?(val) do
        val ~> port
        skip
      end
    end

    write_to_db(val)
    val ~> port
  end
  ```

  The after_failure block will only be executed if a previous call to `react`
  failed. In this case, it would check if the database was updated. If this
  is the case, it sends the value to `port` and it uses `skip/2` to ensure
  the remainder of `react` is not carried out.
  """
  defmacro after_failure(do: body), do: body

  @doc """
  Stop the execution of react, and return the current instance state and spits.

  Using this macro will automatically stop the execution of react. Unlike the
  use of `error/1`, any changes made to the instance state and any values spit
  with `~>/2` will still be returned to the skitter runtime.

  This macro is useful when the execution of react should only continue under
  certain conditions. It is especially useful in an `after_failure/1` body, as
  it can be used to only continue the execution of react if no effect occurred
  in the original call to react.

  Do not provide arguments when using this macro (i.e. just use `skip`), the
  `state` and `output` arguments will automatically be provided by the macro
  expansion of `react/3`
  """
  defmacro skip(state, output) do
    quote generated: true do
      throw {:skitter_skip, unquote(state), unquote(output)}
    end
  end

  # AST Creation / Transformation
  # -----------------------------

  # Remove all `after_failure` blocks from the body
  defp remove_after_failure(body) do
    Macro.postwalk(body, fn
      {:after_failure, _env, _args} -> nil
      any -> any
    end)
  end

  # Remove all occurrences of after_failure if the component has no external
  # effects. Otherwise, leave the body as is.
  defp build_react_after_failure_body(body, meta) do
    if Keyword.has_key?(meta.effects, :external_effect) do
      quote generated: true do
        unquote(body)
      end
    else
      remove_after_failure(body)
    end
  end

  # Create the AST which will become the body of react. Besides this, generate
  # the arguments for the react function header.
  defp create_react_body_and_arg(body) do
    {out_pre, out_post} = create_react_output(body)
    {state_arg, state_post} = create_react_state(body)

    body =
      quote generated: true do
        import unquote(__MODULE__),
          only: [
            ~>: 2,
            skip: 2,
            error: 1,
            read_field: 1,
            write_field: 2,
            after_failure: 1
          ]

        unquote(out_pre)
        unquote(body)
        {:ok, unquote(state_post), unquote(out_post)}
      end

    body = add_skip_handler(body, state_post, out_post)
    body = add_skitter_error_handler(body)

    {body, state_arg}
  end

  # Generate the ASTs which create the initial value of the output, and which
  # return it to the runtime.
  defp create_react_output(body) do
    if_occurrence(body, :~>) do
      {
        quote generated: true do
          unquote(skitter_var(@output_var)) = []
        end,
        quote generated: true do
          unquote(skitter_var(@output_var))
        end
      }
    else
      {nil, []}
    end
  end

  # Generate the ASTs which accept the state argument, and which return it to
  # the runtime
  defp create_react_state(body) do
    {
      if_occurrence(body, :read_field) do
        quote generated: true, do: unquote(skitter_var(@instance_var))
      else
        quote generated: true, do: _state
      end,
      if_occurrence(body, :write_field) do
        quote generated: true, do: unquote(skitter_var(@instance_var))
      else
        nil
      end
    }
  end

  # Add a handler for `skip`, if it is used. If it's not, this just returns the
  # body unchanged.
  # Skip is implemented through the use of a throw. It will simply throw the
  # current values for skitter_state and skitter_output and return them as
  # the result of the block as a whole.
  defp add_skip_handler(body, state, out) do
    if_occurrence(body, :skip) do
      body =
        Macro.postwalk(body, fn
          {:skip, env, []} -> {:skip, env, [state, out]}
          {:skip, env, atom} when is_atom(atom) -> {:skip, env, [state, out]}
          any -> any
        end)

      quote generated: true do
        try do
          unquote(body)
        catch
          {:skitter_skip, state, output} -> {:ok, state, output}
        end
      end
    else
      body
    end
  end

  # Error Checking
  # --------------

  # Check the body of react for some common errors.
  defp check_react_body(args, meta, body) do
    cond do
      # Ensure the inputs can map to the provided argument list
      length(args) != length(meta.in_ports) ->
        inject_error "Different amount of arguments and in_ports"

      # Ensure all spits are valid
      (p = check_spits(meta.out_ports, body)) != nil ->
        inject_error "Port `#{p}` not in out_ports"

      # Ensure after_failure is only used when there are external effects
      count_occurrences(body, :after_failure) > 0 and
          !Keyword.has_key?(meta.effects, :external_effect) ->
        inject_error(
          "`after_failure` only allowed when external_effect is present"
        )

      # Ensure state! is only used when the state can change.
      count_occurrences(body, :write_field) > 0 and
          !Keyword.has_key?(meta.effects, :state_change) ->
        inject_error "Modifying instance state is only allowed when the " <>
                       "state_change effect is present"

      # Fallback case, no errors
      true ->
        nil
    end
  end

  # Verify all spits have an existing out port
  defp check_spits(ports, body) do
    {_, port} =
      Macro.postwalk(body, nil, fn
        ast = {:~>, _env, [_val, port]}, nil ->
          port = name_to_symbol(port)
          {ast, unless(port in ports, do: port)}

        ast, acc ->
          {ast, acc}
      end)

    port
  end

  # -------------- #
  # Init/Terminate #
  # -------------- #

  @doc """
  Instantiate a skitter component.
  """
  defmacro init([arg], meta, do: body) do
    body = transform_field_access(body, meta)

    body =
      quote generated: true do
        import unquote(__MODULE__),
          only: [
            error: 1,
            read_field: 1,
            write_field: 2
          ]

        unquote(skitter_var(@instance_var)) = unquote(create_instance())
        unquote(body)
        {:ok, unquote(skitter_var(@instance_var))}
      end

    body = add_skitter_error_handler(body)

    quote generated: true do
      def __skitter_init__(unquote(arg)) do
        unquote(body)
      end
    end
  end

  @doc """
  Generate component clean up code.

  This macro can be used to clean up any resources before a component instance
  is shut down.
  """
  defmacro terminate([], meta, do: body) do
    body = transform_field_reads(body, meta)
    state_arg = arg_name_if_occurs(body, :read_field, @instance_var)

    body =
      quote generated: true do
        import unquote(__MODULE__), only: [error: 1, read_field: 1]
        unquote(body)
        :ok
      end

    body = add_skitter_error_handler(body)

    quote generated: true do
      def __skitter_terminate__(unquote(state_arg)) do
        unquote(body)
      end
    end
  end

  # ----------- #
  # Checkpoints #
  # ----------- #

  @doc """
  Create a checkpoint.
  """
  defmacro create_checkpoint([], meta, do: body) do
    body = transform_field_reads(body, meta)
    state_arg = arg_name_if_occurs(body, :read_field, @instance_var)
    var = skitter_var(:checkpoint)

    quote generated: true do
      def __skitter_create_checkpoint__(unquote(state_arg)) do
        import unquote(__MODULE__), only: [read_field: 1]
        unquote(var) = unquote(body)
        {:ok, unquote(var)}
      end
    end
  end

  @doc """
  Restore a component instance from a checkpoint.
  """
  defmacro restore_checkpoint([arg], meta, do: body) do
    body = transform_field_access(body, meta)

    quote generated: true do
      def __skitter_restore_checkpoint__(unquote(arg)) do
        import unquote(__MODULE__),
          only: [
            read_field: 1,
            write_field: 2,
            error: 1
          ]

        unquote(skitter_var(@instance_var)) = unquote(create_instance())
        unquote(body)
        {:ok, unquote(skitter_var(@instance_var))}
      end
    end
  end

  @doc """
  Clean up an existing checkpoint.

  Skitter calls this macro when it will not use a certain checkpoint any more.
  This checkpoint is passed as the only input argument to the macro.
  The body of the macro is responsible for cleaning up any resources associated
  with this particular checkpoint.
  """
  defmacro clean_checkpoint([arg], meta, do: body) do
    body = transform_field_reads(body, meta)
    state_arg = arg_name_if_occurs(body, :read_field, @instance_var)

    quote generated: true do
      def __skitter_clean_checkpoint__(unquote(state_arg), unquote(arg)) do
        import unquote(__MODULE__), only: [read_field: 1]
        unquote(body)
        :ok
      end
    end
  end

  # ------------- #
  # Shared Macros #
  # ------------- #

  @doc false
  defmacro read_field(field) do
    quote generated: true do
      unquote(skitter_var(@instance_var)).state.unquote(field)
    end
  end

  @doc false
  defmacro write_field(field, value) do
    var = skitter_var(@instance_var)

    quote generated: true do
      unquote(var) = %{
        unquote(var)
        | state:
            Map.replace!(
              unquote(var).state,
              unquote(field),
              unquote(value)
            )
      }
    end
  end

  @doc """
  Stop the current callback and return with an error.

  A reason should be provided as a string. In certain contexts (e.g. `init/3`),
  the use of this macro will crash the entire workflow.
  """
  defmacro error(reason) do
    quote generated: true do
      throw {:skitter_error, unquote(reason)}
    end
  end

  # --------- #
  # Utilities #
  # --------- #

  # Transform a port name (which is just a standard elixir name) into  a symbol
  # e.g foo becomes :foo
  # If the name is ill-formed, return an {:error, form} pair.
  defp name_to_symbol({name, _env, nil}), do: name
  defp name_to_symbol(any), do: {:error, any}

  # Wrap a body with try/do if the `error/1` macro is used.
  defp add_skitter_error_handler(body) do
    if_occurrence(body, :error) do
      quote generated: true do
        try do
          unquote(body)
        catch
          {:skitter_error, reason} -> {:error, reason}
        end
      end
    else
      quote generated: true do
        unquote(body)
      end
    end
  end

  # Transform reads and writes to fields in the correct order
  defp transform_field_access(body, meta) do
    body |> transform_field_writes(meta) |> transform_field_reads(meta)
  end

  # Transform any use of a field name into a call to `read_field`
  defp transform_field_reads(body, %{fields: fields}) do
    Macro.postwalk(body, fn
      {name, env, atom} when is_atom(atom) ->
        if name in fields do
          quote generated: true, do: read_field(unquote(name))
        else
          {name, env, atom}
        end

      any ->
        any
    end)
  end

  # Transform `name <~ value` into calls to `write_field`
  defp transform_field_writes(body, _) do
    Macro.postwalk(body, fn
      {:<~, _a, [{name, _n, atom}, value]} when is_atom(atom) ->
        quote generated: true, do: write_field(unquote(name), unquote(value))

      any ->
        any
    end)
  end

  # Generate a variable which can only be accessed by skitter macros.
  defp skitter_var(name) do
    # Don't use Macro.var to avoid warnings
    var = {name, [generated: true], __MODULE__}

    quote generated: true do
      var!(unquote(var), unquote(__MODULE__))
    end
  end

  # Create a skitter instance with an empty state.
  defp create_instance() do
    quote generated: true do
      %Skitter.Component.Instance{component: __MODULE__, state: %__MODULE__{}}
    end
  end

  # Count the occurrences of a given symbol in an ast.
  defp count_occurrences(ast, symbol) do
    {_, n} =
      Macro.postwalk(ast, 0, fn
        ast = {^symbol, _env, _args}, acc -> {ast, acc + 1}
        ast, acc -> {ast, acc}
      end)

    n
  end

  # Conditional structure which only get triggered when a certain symbol is
  # present in the AST
  defp if_occurrence(body, atom, do: do_clause, else: else_clause) do
    if count_occurrences(body, atom) >= 1, do: do_clause, else: else_clause
  end

  # Conditional which only gets triggered if a symbol is not present in the AST
  defp unless_occurrence(body, symbol, do: err_clause) do
    if_occurrence(body, symbol, do: nil, else: err_clause)
  end

  # Generate a parameter named `name` if a certain symbol is used in the body.
  # If it is not, use _ instead.
  defp arg_name_if_occurs(body, symbol, name) do
    if_occurrence(body, symbol) do
      quote generated: true do
        unquote(skitter_var(name))
      end
    else
      quote generated: true do
        _
      end
    end
  end
end
