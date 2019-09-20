# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.Handler.Primitives do
  @moduledoc """
  Primitives to be used by component and workflow handlers.

  This module, and any other module in this namespace, provide a set of useful
  primitive functions that can can be used by component or workflow handlers.

  They are included by default when a handler is defined through the use of
  `Skitter.Handler.defhandler/2`.
  """

  alias Skitter.Component
  alias Skitter.Component.Callback

  alias Skitter.Workflow

  alias Skitter.Instance.Prototype

  # ------- #
  # General #
  # ------- #

  @doc """
  Raise a `Skitter.HandlerError`
  """
  def error(for, message) do
    raise(Skitter.Handler.Error, for: for, message: message)
  end

  # ---------- #
  # Definition #
  # ---------- #

  @doc """
  Add `callback` to `component` with `name` if it does not exist yet.
  """
  @spec default_callback(
          Component.t(),
          Component.callback_name(),
          Callback.t()
        ) :: Component.t()
  def default_callback(component = %Component{}, name, callback) do
    if component[name] do
      component
    else
      %{component | callbacks: Map.put(component.callbacks, name, callback)}
    end
  end

  @doc """
  Ensure a component defines a given callback.

  Ensures `component` has a callback named `name` with a certain arity, state
  -and publish capability. If this is not the case, it raises a handler error.
  If it is the case, the component is returned unchanged.

  The following options can be provided:
  - `arity`: the arity the callback should have, defaults to `-1`, which accepts
  any arity.
  - `state_capability`: the state capability that is allowed, defaults to `none`
  - `publish_capability`: the publish capability that is allowed, defaults to
  `false`
  """
  @spec require_callback(Component.t(), Component.callback_name(),
          arity: non_neg_integer(),
          state: Callback.state_capability(),
          publish: Callback.publish_capability()
        ) ::
          Component.t() | no_return()
  def require_callback(component = %Component{}, name, opts \\ []) do
    arity = Keyword.get(opts, :arity, -1)
    state = Keyword.get(opts, :state_capability, :none)
    publish = Keyword.get(opts, :publish_capability, false)

    if cb = component[name] do
      permissions? = Callback.check_permissions(cb, state, publish)
      arity? = Callback.check_arity(cb, arity)

      if permissions? and arity? do
        component
      else
        error(
          component,
          "Invalid implementation of #{name}.\n" <>
            "Wanted: state_capability: #{state}, publish_capability: " <>
            "#{publish}, arity: #{arity}.\n Got: #{inspect(cb)}"
        )
      end
    else
      error(component, "Missing `#{name}` callback")
    end
  end

  # Inline Workflow
  # ---------------

  @doc """
  Inline any child workflow which has `handler` as its handler.
  """
  def inline_workflows_with_handler(wf, atom) when is_atom(atom) do
    inline_workflows_with_handler(wf, Skitter.Runtime.Registry.get(atom))
  end

  def inline_workflows_with_handler(wf = %Workflow{nodes: nodes}, handler) do
    ids =
      nodes
      |> Enum.filter(fn
        {_, %Prototype{elem: %Workflow{handler: ^handler}}} -> true
        _ -> false
      end)
      |> Enum.map(&elem(&1, 0))

    Enum.reduce(ids, wf, fn id, wf -> inline_workflow(wf, id) end)
  end

  def inline_workflow(w = %Workflow{nodes: nodes, links: links}, id) do
    links = update_parent_destinations(nodes, links, id)
    links = add_child_links(nodes, links, id)
    nodes = add_child_nodes(nodes, id)

    %{w | nodes: Enum.into(nodes, %{}), links: Enum.into(links, %{})}
  end

  # Any link that points to the in port of element `id` should point to the
  # destinations of that in port instead. Ensure those destinations are prefixed
  defp update_parent_destinations(nodes, links, id) do
    Enum.map(links, fn {src, dsts} ->
      {src, Enum.flat_map(dsts, &update_parent_links(&1, nodes, id))}
    end)
  end

  defp update_parent_links(dst = {id, port}, nodes, id) do
    case nodes[id] do
      nil ->
        [dst]

      %Prototype{elem: %Workflow{links: links}} ->
        links
        |> Map.get({nil, port}, [])
        |> Enum.map(&update_child_address(&1, id))
    end
  end

  defp update_parent_links(dst, _nodes, _id), do: [dst]

  # Add internal links of nested workflows to parent workflow.
  # Replace outgoing links of workflow with direct links from nodes sending to
  # out port.
  defp add_child_links(nodes, links, id) do
    destinations = gather_destinations(links, id)

    # Remove links that leave from target workflow in parent workflow
    parent_links = Enum.reject(links, fn {{src_id, _}, _} -> src_id == id end)

    # Change internal links of child workflow so they can be embedded in parent
    # Links from in nodes were handled in previous steps, so filter them out
    child_links =
      nodes[id].elem.links
      |> Enum.reject(fn {{src, _}, _} -> is_nil(src) end)
      |> Enum.map(&update_child_link(&1, id, destinations))

    parent_links ++ child_links
  end

  defp update_child_link({src, dsts}, pre, destinations) do
    src = update_child_address(src, pre)

    dsts =
      Enum.flat_map(dsts, fn
        {nil, port} -> Map.get(destinations, port, [])
        address -> [update_child_address(address, pre)]
      end)

    {src, dsts}
  end

  defp update_child_address({id, port}, pre), do: {prefix(id, pre), port}

  # Get all the outgoing links for a given node
  defp gather_destinations(links, id) do
    Enum.reduce(links, %{}, fn
      {{^id, p}, d}, a -> Map.put(a, p, d)
      _, a -> a
    end)
  end

  defp add_child_nodes(nodes, id) do
    %Prototype{elem: %Workflow{nodes: child_nodes}} = nodes[id]
    child_nodes = Enum.map(child_nodes, fn {n, p} -> {prefix(n, id), p} end)
    parent_nodes = nodes |> Map.delete(id) |> Map.to_list()
    parent_nodes ++ child_nodes
  end

  defp prefix(name, prefix) do
    String.to_atom("#{Atom.to_string(prefix)}_#{Atom.to_string(name)}")
  end

  # --------- #
  # Callbacks #
  # --------- #

  defdelegate create_empty_state(component), to: Component
  defdelegate call(component, callback_name, state, args), to: Component
end
