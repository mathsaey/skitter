# Copyright 2018 - 2020, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

defmodule Skitter.DSL.NamedTest do
  use ExUnit.Case, async: true
  import Skitter.DSL.Test.Assertions

  import Skitter.DSL.Named

  test "store and load" do
    store(42, Foo)

    assert load(Foo) == 42
  end

  test "error when name is not defined" do
    assert_definition_error "`DoesNotExist` is not defined" do
      load(DoesNotExist)
    end
  end

  test "error when name is already defined" do
    assert_definition_error "`AlreadyDefined` is already defined" do
      store(42, AlreadyDefined)
      store(:foo, AlreadyDefined)
    end
  end
end
