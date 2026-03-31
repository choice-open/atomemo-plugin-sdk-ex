defmodule AtomemoPluginSdk.ParameterValidator.StringTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterValidator.String, as: PVString

  describe "validate/3" do
    test "returns ok for valid string" do
      definition = %PDString{min_length: 1, max_length: 10}

      assert {:ok, "hello"} = PVString.validate(definition, "hello", path: [:default])
    end

    test "returns error when value is not a string" do
      definition = %PDString{}

      assert {:error, [%{path: :type, message: "must be a string."}]} =
               PVString.validate(definition, 123, path: [:default])
    end

    test "returns error when value is shorter than min_length" do
      definition = %PDString{min_length: 2}

      assert {:error, %{path: :min, message: "should be at least 2 character(s)"}} =
               PVString.validate(definition, "a", path: [:default])
    end

    test "returns error when value is longer than max_length" do
      definition = %PDString{max_length: 3}

      assert {:error, %{path: :max, message: "should be at most 3 character(s)"}} =
               PVString.validate(definition, "toolong", path: [:default])
    end
  end
end
