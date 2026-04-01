defmodule AtomemoPluginSdk.ParameterValidator.BooleanTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.Boolean, as: PDBoolean
  alias AtomemoPluginSdk.ParameterValidator.Boolean, as: PVBoolean

  describe "validate/3" do
    test "returns ok for boolean true" do
      assert {:ok, true} = PVBoolean.validate(%PDBoolean{}, true, path: [:default])
    end

    test "returns ok for boolean false" do
      assert {:ok, false} = PVBoolean.validate(%PDBoolean{}, false, path: [:default])
    end

    test "returns error when value is not boolean" do
      assert {:error, %{path: :type, message: "must be a boolean."}} =
               PVBoolean.validate(%PDBoolean{}, 1, path: [:default])
    end
  end
end
