defmodule AtomemoPluginSdk.ParameterDefinition.ArrayTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.Array, as: PDArray

  test "allows default values" do
    assert PDArray.__allow_default__() == true
  end
end
