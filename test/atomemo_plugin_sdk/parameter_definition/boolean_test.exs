defmodule AtomemoPluginSdk.ParameterDefinition.BooleanTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.Boolean, as: PDBoolean

  test "allows default values" do
    assert PDBoolean.__allow_default__() == true
  end
end
