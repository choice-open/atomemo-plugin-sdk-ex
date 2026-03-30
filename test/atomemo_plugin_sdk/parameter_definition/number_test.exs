defmodule AtomemoPluginSdk.ParameterDefinition.NumberTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.Number, as: PDNumber

  test "allows default values" do
    assert PDNumber.__allow_default__() == true
  end
end
