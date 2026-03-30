defmodule AtomemoPluginSdk.ParameterDefinition.ObjectTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.Object, as: PDObject

  test "allows default values" do
    assert PDObject.__allow_default__() == true
  end
end
