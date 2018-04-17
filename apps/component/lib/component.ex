defmodule Skitter.Component do
  @moduledoc """
  """

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

    quote do
      defmodule unquote(name) do
        import unquote(__MODULE__).Internal, only: [
          react: 3, init: 3
        ]

        def __skitter_metadata__, do: unquote(Macro.escape(metadata))

        unquote(body)
      end
    end
  end

  # AST Identifiers
  # ---------------

  @component_callbacks [:react, :init]

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
  # where all the arguments (except for the the do block, which is the final
  # argument) are wrapped inside a list. Provide the component metadata and
  # do block as the second and third argument.
  # Thus, a call to macro `foo(a,b) do ...` turns into `foo([a,b], meta) do ...`
  # This makes it possible to use arbitraty pattern matching in `react`, etc
  # It also provides the various callbacks information about the component.
  defp callback_postwalk({name, env, argLst}, meta)
  when name in @component_callbacks do
    {args, [block]} = Enum.split(argLst, -1)
    {{name, env, [args, meta, block]}, meta}
  end
  # Transform @internal_function_keyword into defp.
  defp callback_postwalk({:helper, env, rest}, meta) do
    {{:defp, env, rest}, meta}
  end
  defp callback_postwalk(any, meta), do: {any, meta}

  # Utility Functions
  # -----------------
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

  # Internal Macros
  # ---------------
  # Macros to be used inside component/3

  defmodule Internal do
    @moduledoc false

    @doc """
    Read the current component instance
    """
   defmacro instance do
     quote do var!(skitter_instance) end
   end

   @doc """
    Create or modify the instance of a component.
   """
   defmacro instance(value) do
     quote generated: true do
       var!(skitter_instance) = unquote(value)
     end
   end

   @doc """
   Send a value to an output port.
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

    # TODO: postwalk to check for instance use
    # TODO: don't use output when not needed
    defmacro react(args, _meta, do: body) do
      quote do
        def __skitter_react__(var!(skitter_instance), unquote(args)) do
          import unquote(__MODULE__), only: [instance: 1, spit: 2]
          var!(skitter_output) = []
          unquote(body)
          {:ok, var!(skitter_instance), var!(skitter_output)}
        end
      end
    end
  end

  # ----------------- #
  # Auxiliary Modules #
  # ----------------- #

  defmodule DefinitionError do
    @moduledoc """
    This error is raised when a component definition is invalid.
    """
    defexception [:message]

    def exception(val) do
      %DefinitionError{message: val}
    end
  end

  defmodule BadCallError do
    @moduledoc """
    This error is raised when a function is called on a component that does not
    support it (due to its effects)
    """
    defexception [:message]

    def exception(val) do
      %BadCallError{message: val}
    end
  end
end
