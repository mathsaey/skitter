# Copyright 2018, 2019 Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.PortTest do
  use ExUnit.Case, async: true
  alias Skitter.Port

  describe "parsing port lists" do
    test "works on complete input" do
      assert Port.parse_list(quote(do: [in: [a, b], out: [c, d]]), nil) ==
               {[:a, :b], [:c, :d]}
    end

    test "works on incomplete input" do
      assert Port.parse_list(quote(do: [in: [a, b]]), nil) == {[:a, :b], []}
    end

    test "works on non-list input" do
      assert Port.parse_list(quote(do: [in: a, out: b]), nil) == {[:a], [:b]}
      assert Port.parse_list(quote(do: [in: a]), nil) == {[:a], []}
    end

    test "throws correctly" do
      assert catch_throw(Port.parse_list(quote(do: [in: :foo]), nil)) ==
               {:error, :invalid_syntax, :foo, nil}

      assert catch_throw(Port.parse_list(quote(do: [foo]), nil)) ==
               {:error, :invalid_port_list, quote(do: [foo]), nil}
    end
  end
end
