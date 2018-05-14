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

  # ------------------- #
  # Component Callbacks #
  # ------------------- #
  # Callbacks that each skitter component should implement.
  #
  # All of these callbacks should be automatically provided when the
  # `component/3` macro is used. Nevertheless, we provide a behaviour to get an
  # early warning if the `component/3` DSL generates incorrect code.
  #
  # Although it is possible to implement these callbacks correctly, it is
  # preferable to use the `component/3` macro, as it verifies whether or not
  # the provided component is a legal skitter component.

  @type component :: module()
  @type instance :: any()

  @callback __skitter_metadata__ :: %{
              name: String.t(),
              description: String.t(),
              effects: [keyword()],
              in_ports: [atom()],
              out_ports: [atom()]
            }

  @callback __skitter_init__([]) :: {:ok, instance}

  @callback __skitter_react__(instance, []) :: {:ok, instance, [keyword()]}
  @callback __skitter_react_after_failure__(instance, []) ::
              {:ok, instance, [keyword()]}

  # ----------------- #
  # Shared Macro Code #
  # ----------------- #
  # Code used by both `component/3` and various internal macros.

  # Constants
  # ---------

  @valid_effects [internal_state: [], external_effects: []]

  @component_callbacks [:react, :init]

  @default_callbacks [:init]

  # AST Transformations
  # -------------------

  # Transform a port name (which is just a standard elixir name) into  a symbol
  # e.g foo becomes :foo
  # If the name is ill-formed, return an {:error, form} pair.
  defp transform_port_name({name, _env, nil}), do: name
  defp transform_port_name(any), do: {:error, any}

  # Utility Functions
  # -----------------

  # Count the occurrences of a given symbol in an ast.
  defp count_occurrences(symbol, ast) do
    {_, n} =
      Macro.postwalk(ast, 0, fn
        ast = {^symbol, _env, _args}, acc -> {ast, acc + 1}
        ast, acc -> {ast, acc}
      end)

    n
  end

  # -------------------- #
  # Component Generation #
  # -------------------- #

  @doc """
  Create a skitter component.
  """
  defmacro component(name, ports, do: body) do
    # Get metadata from header
    full_name = module_name_to_snake_case(Macro.expand(name, __CALLER__))
    {in_ports, out_ports} = read_ports(ports)

    # Extract metadata from body AST
    {body, desc} = extract_description(body)
    {body, effects} = extract_effects(body)

    # Gather metadata
    metadata = %{
      name: full_name,
      description: desc,
      effects: effects,
      in_ports: in_ports,
      out_ports: out_ports
    }

    # Add default callbacks
    defaults = generate_default_callbacks(metadata, body)

    # Transform macro calls inside body AST
    body = transform_component_callbacks(body, metadata)

    # Check for errors
    errors = check_component_body(metadata, body)

    quote do
      defmodule unquote(name) do
        @behaviour unquote(__MODULE__)
        import unquote(__MODULE__),
          only: [
            react: 3,
            init: 3
          ]

        def __skitter_metadata__, do: unquote(Macro.escape(metadata))

        unquote(body)
        unquote(errors)
        unquote(defaults)
      end
    end
  end

  # AST Transformations
  # -------------------
  # Transformations applied to the body provided to component/3

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

  # Transform all calls to macros in the `@component_callbacks` list to calls
  # where all the arguments (except for the do block, which is the final
  # argument) are wrapped inside a list. Provide the component metadata and
  # do block as the second and third argument.
  # Thus, a call to macro `foo(a,b) do ...` turns into `foo([a,b], meta) do ...`
  # This makes it possible to use arbitrary pattern matching in `react`, etc
  # It also provides the various callbacks information about the component.
  # Furthermore, any calls to helper are transformed into `defp`
  defp transform_component_callbacks(body, meta) do
    Macro.postwalk(body, fn
      {name, env, arg_lst}
      when name in @component_callbacks ->
        {args, [block]} = Enum.split(arg_lst, -1)
        {name, env, [args, meta, block]}

      {:helper, env, rest} ->
        {:defp, env, rest}

      any ->
        any
    end)
  end

  # Retrieve the description from a component if it is present.
  # A description is provided when the component body start with a string.
  # If this is the case, remove the string from the body and use it as the
  # component description.
  # If it is not the case, leave the component body untouched.
  defp extract_description({:__block__, env, [str | r]}) when is_binary(str) do
    {{:__block__, env, r}, str}
  end

  defp extract_description(str) when is_binary(str),
    do:
      {quote do
       end, str}

  defp extract_description(any), do: {any, ""}

  # Utility Functions
  # -----------------
  # Functions used when expanding the component/3 macro

  # Generate a readable string (i.e. a string with spaces) based on the name
  # of a component.
  defp module_name_to_snake_case(name) do
    name = name |> Atom.to_string() |> String.split(".") |> Enum.at(-1)
    regex = ~r/([[:upper:]]+(?=[[:upper:]]|$)|[[:upper:]][[:lower:]]*)/
    regex |> Regex.replace(name, " \\0") |> String.trim()
  end

  # Parse the port lists, add an empty list for out ports if they are not
  # provided
  defp read_ports(in: in_ports), do: read_ports(in: in_ports, out: [])

  defp read_ports(in: in_ports, out: out_ports) do
    {parse_port_names(in_ports), parse_port_names(out_ports)}
  end

  # Parse the various ports names encountered in the port list.
  defp parse_port_names(lst) when is_list(lst) do
    Enum.map(lst, &transform_port_name/1)
  end

  # Allow single names to be specified outside of a list
  #   e.g. in: foo will become in: [foo]
  # Leave the actual parsing up to the list variant of this function.
  defp parse_port_names(el), do: parse_port_names([el])

  # Default Generation
  # ------------------
  # Default implementations of various skitter functions
  # We cannot use defoverridable, as the compiler will remove it before
  # the init, react, ... macros are expanded.

  defp generate_default_callbacks(_meta, body) do
    # We cannot store callbacks in attributes, so we store them in a map here.
    defaults = %{init: &default_init/0}

    Enum.map(@default_callbacks, fn name ->
      if count_occurrences(name, body) >= 1 do
        nil
      else
        defaults[name].()
      end
    end)
  end

  defp default_init() do
    quote do
      def __skitter_init__(_), do: {:ok, nil}
    end
  end

  # Error Checking
  # --------------
  # Functions that check if the component as a whole is correct

  defp check_component_body(meta, body) do
    [
      check_effects(meta),
      check_react(meta, body),
      check_port_names(meta[:in_ports]),
      check_port_names(meta[:out_ports])
    ]
  end

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
    for {effect, properties} <- metadata[:effects] do
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

  defp check_react(meta, body) do
    unless count_occurrences(:react, body) >= 1 do
      inject_error "Component `#{meta.name}` lacks a react implementation"
    end
  end

  # ------------- #
  # Shared Macros #
  # ------------- #
  # Macros which are usable inside multiple callbacks inside component.

  @doc """
  Fetch the current component instance.

  Elixir will emit warnings about the `skitter_instance` variable if some
  error with the instance variable occurs.

  Usable inside `react/3`, `init/3`.
  """
  defmacro instance do
    quote do
      var!(skitter_instance)
    end
  end

  @doc """
  Modify the instance of the component.

  Usable inside `init/3`, and inside `react/3` iff the component is marked
  with the `:internal_state` effect.

  Elixir will emit warnings about the `skitter_instance` variable if some
  error with the instance variable occurs.
  """
  defmacro instance!(value) do
    quote do
      var!(skitter_instance) = unquote(value)
    end
  end

  # --------------- #
  # Init Generation #
  # --------------- #

  defmacro init(args, _meta, do: body) do
    quote do
      def __skitter_init__(unquote(args)) do
        import unquote(__MODULE__), only: [instance!: 1]
        unquote(body)
        {:ok, var!(skitter_instance)}
      end
    end
  end

  # ---------------- #
  # React Generation #
  # ---------------- #

  defmacro react(args, meta, do: body) do
    body = body |> transform_spit() |> transform_instance()
    errors = check_react_body(args, meta, body)

    react_body = remove_after_failure(body)
    react_after_failure_body = build_react_after_failure_body(body, meta)

    {react_body, react_arg} = create_react_body_and_arg(react_body)
    {fail_body, fail_arg} = create_react_body_and_arg(react_after_failure_body)

    quote do
      unquote(errors)

      def __skitter_react__(unquote(react_arg), unquote(args)) do
        unquote(react_body)
      end

      def __skitter_react_after_failure__(unquote(fail_arg), unquote(args)) do
        unquote(fail_body)
      end
    end
  end

  # Internal Macros
  # ---------------

  @doc """
  Provide a value to the workflow on a given port.

  The given value will be sent to every other component that is connected to
  the provided output port of the component.
  The value will be sent _after_ `react/3` has finished executing.

  Usable inside `react/3` iff the component has an output port.
  """
  defmacro spit(port, value) do
    quote do
      var!(skitter_output) =
        Keyword.put(
          var!(skitter_output),
          unquote(port),
          unquote(value)
        )
    end
  end

  @doc """
  Code that should only be executed after a failure occurred.

  The code in this block will only be executed if `react/3` is triggered
  after a failure occurred.
  Internally, this operation is a no-op. Post walks will filter out calls
  to this macro when needed.

  Usable inside `react/3` iff the component has an external state.
  """
  defmacro after_failure(do: body), do: body

  # AST Creation
  # ------------

  defp create_react_body_and_arg(body) do
    {out_pre, out_post} = create_react_output(body)
    {inst_arg, inst_pre, inst_post} = create_react_instance(body)

    body =
      quote do
        import unquote(__MODULE__), only: [spit: 2, instance: 0, instance!: 1]
        unquote(inst_pre)
        unquote(out_pre)
        unquote(body)
        {:ok, unquote(inst_post), unquote(out_post)}
      end

    {body, inst_arg}
  end

  # Generate the ASTs for creating the initial value and reading the value
  # of skitter_output.
  def create_react_output(body) do
    spit_use_count = count_occurrences(:spit, body)

    if spit_use_count > 0 do
      {
        quote do
          var!(skitter_output) = []
        end,
        quote do
          var!(skitter_output)
        end
      }
    else
      {nil, []}
    end
  end

  def create_react_instance(body) do
    read_count = count_occurrences(:instance, body)
    write_count = count_occurrences(:instance!, body)

    arg =
      if read_count > 0 do
        quote do: var!(instance_arg)
      else
        quote do: _instance_arg
      end

    pre =
      if read_count > 0 do
        quote do: var!(skitter_instance) = var!(instance_arg)
      else
        nil
      end

    post =
      if write_count > 0 do
        quote do: var!(skitter_instance)
      else
        nil
      end

    {arg, pre, post}
  end

  # Create the body of __skitter_react_after_failure depending on the
  # effects of the components.
  defp build_react_after_failure_body(body, meta) do
    if Keyword.has_key?(meta[:effects], :external_effects) do
      quote do
        import unquote(__MODULE__), only: [after_failure: 1]
        unquote(body)
      end
    else
      remove_after_failure(body)
    end
  end

  # AST Transformations
  # -------------------

  # Remove all `after_failure` blocks from the body
  defp remove_after_failure(body) do
    Macro.postwalk(body, fn
      {:after_failure, _env, _args} -> nil
      any -> any
    end)
  end

  # Transform all instances of 'instance' into 'instance()'
  # This is done to avoid ambigous uses of instance, which
  # will cause elixir to show a warning.
  defp transform_instance(body) do
    Macro.postwalk(body, fn
      {:instance, env, atom} when is_atom(atom) ->
        {:instance, env, []}

      any ->
        any
    end)
  end

  # Transform all spit calls in the body:
  #   spit 5 + 2 -> port becomes spit :port, 5 + 2
  defp transform_spit(body) do
    Macro.postwalk(body, fn
      {:spit, env, [{:~>, _ae, [body, port = {_name, _pe, _pargs}]}]} ->
        {:spit, env, [transform_port_name(port), body]}

      any ->
        any
    end)
  end

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

      # Ensure after_failure is only used when there are external effects
      count_occurrences(:after_failure, body) > 0 and
          !Keyword.has_key?(meta[:effects], :external_effects) ->
        inject_error(
          "`after_failure` only allowed when external_effects are present"
        )

      # Ensure instance! is only used when there is an internal state
      count_occurrences(:instance!, body) > 0 and
          !Keyword.has_key?(meta[:effects], :internal_state) ->
        inject_error(
          "`instance!` only allowed when the internal_state effect is present"
        )

      # Fallback case, no errors
      true ->
        nil
    end
  end

  # Check the spits in the body of react through `port_check_postwalk/2`
  # Verify that:
  #   - no errors occured when parsing port names
  #   - The output port is present in the output port list
  defp check_spits(ports, body) do
    {_, {_ports, port}} =
      Macro.postwalk(body, {ports, nil}, fn
        ast = {:spit, _env, [{:error, port}, _val]}, {ports, nil} ->
          {ast, {ports, port}}

        ast = {:spit, _env, [port, _val]}, {ports, nil} ->
          if port in ports, do: {ast, {ports, nil}}, else: {ast, {ports, port}}

        ast, acc ->
          {ast, acc}
      end)

    port
  end
end
