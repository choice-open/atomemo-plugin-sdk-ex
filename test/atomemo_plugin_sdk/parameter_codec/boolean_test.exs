defmodule AtomemoPluginSdk.ParameterCodec.BooleanTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.Boolean, as: PDBoolean
  alias AtomemoPluginSdk.ParameterError.Entry

  describe "cast/2" do
    test "returns ok for true" do
      assert {:ok, true} = Codecable.cast(%PDBoolean{}, true)
    end

    test "returns ok for false" do
      assert {:ok, false} = Codecable.cast(%PDBoolean{}, false)
    end

    test "returns error for integer" do
      assert {:error, [%Entry{path: [], message: "must be a boolean."}]} =
               Codecable.cast(%PDBoolean{name: "field"}, 1)
    end

    test "returns error for string" do
      assert {:error, [%Entry{message: "must be a boolean."}]} =
               Codecable.cast(%PDBoolean{}, "true")
    end

    test "returns error for nil" do
      assert {:error, [%Entry{message: "must be a boolean."}]} =
               Codecable.cast(%PDBoolean{}, nil)
    end
  end

  describe "cast_for_internal_default/2" do
    test "delegates to cast for valid default" do
      assert {:ok, true} = Codecable.cast_for_internal_default(%PDBoolean{}, true)
    end

    test "returns error for invalid default type" do
      assert {:error, [%Entry{message: "must be a boolean."}]} =
               Codecable.cast_for_internal_default(%PDBoolean{}, "true")
    end
  end
end
