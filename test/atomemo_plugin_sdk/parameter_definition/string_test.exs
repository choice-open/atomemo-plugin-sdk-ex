defmodule AtomemoPluginSdk.ParameterDefinition.StringTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString

  test "allows default values" do
    assert PDString.__allow_default__() == true
  end
end
