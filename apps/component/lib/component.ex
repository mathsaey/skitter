# ------------ #
# Error Module #
# ------------ #

defmodule Skitter.Component.DefinitionError do
  @moduledoc """
  This error is raised when a component definition is invalid.
  """
  defexception [:message]
  def exception(val), do: %__MODULE__{message: val}

  @doc """
  Return a quoted raise statement which can be injected by a macro.

  When activated, the statement will raise a DefinitionError with `reason`.
  """
  def inject_error(reason) do
    quote do
      import unquote(__MODULE__)
      raise Skitter.Component.DefinitionError, unquote(reason)
    end
  end
end

defmodule Skitter.Component do
  @moduledoc """
  """

  import Skitter.Component.DefinitionError

  # ------------------- #
  # Component Interface #
  # ------------------- #

  @doc """
  Returns the name of a component.

  The name of a component is automatically generated based on the component
  name provided to `component/3`.
  """
  def name(comp), do: comp.__skitter_metadata__.name

  @doc """
  Returns the description of a component.

  The description of a component can be provided by adding a string as the first
  element of the `component/3` body.
  An empty string is returned if no documentation is present.

  ## Example

  ```
  component Example, in: [:in], out: [:out] do
    "Your description goes here"
  end
  ```
  """
  def description(comp), do: comp.__skitter_metadata__.description

  @doc """
  Return the effects of a component.

  TODO: Add more information about this later.
  """
  def effects(comp), do: comp.__skitter_metadata__.effects

  @doc """
  Return the in ports of a component.

  TODO: Add more information about this later.
  """
  def in_ports(comp), do: comp.__skitter_metadata__.in_ports

  @doc """
  Return the in ports of a component.

  TODO: Add more information about this later.
  """
  def out_ports(comp), do: comp.__skitter_metadata__.out_ports

  # -------------------- #
  # Component Generation #
  # -------------------- #

  # Constants
  # ---------

  @valid_effects [internal_state: [], external_effects: []]

  @component_callbacks [:react, :init]


  # Main Definition
  # ---------------

  @doc """
  Create a skitter component.
  """
  defmacro component(name, ports, do: body) do
    # Get metadata from header
    full_name = full_name(Macro.expand(name, __CALLER__))
    {in_ports, out_ports} = read_ports(ports)

    # Extract metadata from body AST
    {body, desc} = extract_description(body)
    {body, effects} = Macro.postwalk(body, [], &effect_postwalk/2)

    # Gather metadata
    metadata = %{
      name: full_name, description: desc,
      effects: effects, in_ports: in_ports, out_ports: out_ports
    }

    # Transform macro calls inside body AST
    {body, _} = Macro.postwalk(body, metadata, &callback_postwalk/2)

    # Check for errors
    errors = check_component_body(metadata, body)

    quote do
      defmodule unquote(name) do
        import unquote(__MODULE__).Internal, only: [
          react: 3, init: 3
        ]

        def __skitter_metadata__, do: unquote(Macro.escape(metadata))

        unquote(errors)
        unquote(body)
      end
    end
  end

  # AST Transformation
  # ------------------
  # Transformations applied to the body provided to component/3

  # Extract effect declarations from the AST and add the effects to the effect
  # list.
  # Effects are specified as either:
  #  effect effect_name property1, property2
  #  effect effect_name
  # In both cases, the full statement will be removed from the ast, and the
  # effect will be added to the accumulator with its properties.
  defp effect_postwalk({:effect, _env, [effect]}, acc) do
    {effect, properties} = Macro.decompose_call(effect)
    properties = Enum.map properties, fn {name, _env, _args} -> name end
    {nil, Keyword.put(acc, effect, properties)}
  end
  # Ignore non-effect nodes in the AST
  defp effect_postwalk(any, acc), do: {any, acc}

  # Transform all calls to macros in the `@component_callbacks` list to calls
  # where all the arguments (except for the do block, which is the final
  # argument) are wrapped inside a list. Provide the component metadata and
  # do block as the second and third argument.
  # Thus, a call to macro `foo(a,b) do ...` turns into `foo([a,b], meta) do ...`
  # This makes it possible to use arbitrary pattern matching in `react`, etc
  # It also provides the various callbacks information about the component.
  defp callback_postwalk({name, env, argLst}, meta)
  when name in @component_callbacks do
    {args, [block]} = Enum.split(argLst, -1)
    {{name, env, [args, meta, block]}, meta}
  end
  # Transform helper into defp.
  defp callback_postwalk({:helper, env, rest}, meta) do
    {{:defp, env, rest}, meta}
  end
  # Ignore everything else
  defp callback_postwalk(any, meta), do: {any, meta}

  # Data Extraction
  # ---------------
  # Functions used when expanding the component/3 macro

  # Generate a readable string (i.e. a string with spaces) based on the name
  # of a component.
  defp full_name(name) do
    regex = ~r/([[:upper:]]+(?=[[:upper:]]|$)|[[:upper:]][[:lower:]]*)/
    name  = name |> Atom.to_string |> String.split(".") |> Enum.at(-1)
    Regex.replace(regex, name, " \\0") |> String.trim
  end

  # Verify the ports keyword list
  # TODO: expand on this later:
  #   - Allow a single port instead of a full list
  #   - Throw errors when the list is in the wrong format
  defp read_ports([in: in_ports]), do: {in_ports, []}
  defp read_ports([in: in_ports, out: out_ports]), do: {in_ports, out_ports}

  # Retrieve the description from a component if it is present.
  # A description is provided when the component body start with a string.
  # If this is the case, remove the string from the body and use it as the
  # component description.
  # If it is not the case, leave the component body untouched.
  defp extract_description({:__block__, env, [str | r]}) when is_binary(str) do
    {{:__block__, env, r}, str}
  end
  defp extract_description(str) when is_binary(str), do: {quote do end, str}
  defp extract_description(any), do: {any, ""}

  # Error Checking
  # --------------
  # Functions that check if the component as a whole is correct

  defp check_component_body(meta, _body) do
    check_effects(meta)
  end

  # Check if the specified effects are valid.
  # If they are, ensure their properties are valid as well.
  defp check_effects(metadata) do
    for {effect, properties} <- metadata[:effects] do
      with valid when valid != nil  <- Keyword.get(@valid_effects, effect),
           [] <- Enum.reject(properties, fn p -> p in valid end)
      do
        nil
      else
        nil ->
          inject_error "Effect `#{effect}` is not valid"
        [prop | _] ->
          inject_error "`#{prop}` is not a valid property of `#{effect}`"
      end
    end
  end

  # ------------------- #
  # Component Callbacks #
  # ------------------- #

  defmodule Internal do
    @moduledoc """
    Macros to be used inside `Skitter.Component.component/3`

    __This module is automatically imported by `Skitter.Component.component/3`,
    do not import it manually.__

    The Macros in this module are used inside the body of
    `Skitter.Component.component/3` to generate a component definition.
    Be sure to read its documentation before proceeding.

    ## Warning

    Calls to the macros in this module are often modified by the
    `Skitter.Component.component/3` macro.
    Therefore, you cannot always call the macros in this module like you
    would expect.
    The documentation in this module is only present for extra explanation,
    __do not manually call these macros outside of the body of
    `Skitter.Component.component/3`.__
    The documentation will contain examples of the correct syntax of the use of
    these macros when needed.
    """

    import Skitter.Component.DefinitionError

    @doc """
    Fetch the current component instance.

    Elixir will emit warnings about the `skitter_instance` variable if some error
    with the instance variable occurs.

    Usable inside `react/3`, `init/3`.
    """
    defmacro instance do
      quote do var!(skitter_instance) end
    end

    @doc """
    Modify the instance of the component, __do not call this directly__.

    Automatically generated when `instance = something` is encountered inside a
    component callback.
    Usable inside `init/3`, and inside `react/3` iff the component is marked with
    the `:internal_state` effect.

    Elixir will emit warnings about the `skitter_instance` variable if some error
    with the instance variable occurs.

    ## Example

    ```
    component MyComponent, in: [:foo, :bar] do
      init external_value do
        instance = external_value
      end
    end
    """
    defmacro instance(value) do
      quote generated: true do
        var!(skitter_instance) = unquote(value)
      end
    end

    @doc """
    Provide a value to the workflow on a given port.

    The given value will be sent to every other component that is connected to
    the provided output port of the component.
    The value will be sent _after_ `react/3` has finished executing.

    Usable inside `react/3` iff the component has an output port.
    """
    defmacro spit(port, value) do
      quote do
        var!(skitter_output) = Keyword.put(
          var!(skitter_output), unquote(port), unquote(value)
        )
      end
    end

    defmacro init(args, _meta, do: body) do
      quote do
        def __skitter_init__(unquote(args)) do
          import unquote(__MODULE__), only: [instance: 1]
          unquote(body)
          {:ok, var!(skitter_instance)}
        end
      end
    end

    # ---------------- #
    # React Generation #
    # ---------------- #

    # TODO:
    #   - postwalk to check for instance use
    defmacro react(args, meta, do: body) do
      errors = check_react_body(args, meta, body)
      {output_pre, output_post} = create_react_output(args, meta, body)

      quote do
        unquote(errors)
        def __skitter_react__(instance, unquote(args)) do
          import unquote(__MODULE__), only: [instance: 1, spit: 2]
          unquote(output_pre)
          unquote(body)
          {:ok, var!(skitter_instance), unquote(output_post)}
        end
      end
    end

    # Skitter Output Generation
    # -------------------------

    # Generate the ASTs for creating the initial value and reading the value
    # of skitter_output.
    def create_react_output(_args, _meta, body) do
      {_, port_use_count} = Macro.postwalk(body, 0, &port_count_postwalk/2)
      if port_use_count > 0 do
        {
          quote do var!(skitter_ouput) = [] end,
          quote do var!(skitter_ouput) end
        }
      else
        {nil, nil}
      end
    end

    # Count the occurences of `spit` in the ast.
    defp port_count_postwalk(ast = {:spit, _e, _p}, acc), do: {ast, acc + 1}
    defp port_count_postwalk(ast, acc), do: {ast, acc}

    # Error Checking
    # --------------

    # Check the body of react for some common errors.
    defp check_react_body(args, meta, body) do
      cond do
        # Ensure the inputs can map to the provided argument list
        length(args) != length(meta[:in_ports]) ->
          inject_error "Different amount of arguments and in_ports"
        # Ensure all spits are valid
        (p = check_spits(meta[:out_ports], body)) != nil ->
          inject_error "Port `#{p}` not in out_ports"
        true -> nil
      end
    end

    # Check the spits in the body of react through `port_check_postwalk/2`
    defp check_spits(ports, body) do
      {_, {_ports, port}} =
        Macro.postwalk(body, {ports, nil}, &port_check_postwalk/2)
      port
    end
    # Check all the calls to spit and verify that the output port exists.
    # If it does not, put the output port in the accumulator
    defp port_check_postwalk(ast = {:spit, _env, [port, _val]}, {ports, nil}) do
      if port in ports, do: {ast, {ports, nil}}, else: {ast, {ports, port}}
    end
    # Fallback match, don't do anything
    defp port_check_postwalk(ast, acc), do: {ast, acc}
  end
end

