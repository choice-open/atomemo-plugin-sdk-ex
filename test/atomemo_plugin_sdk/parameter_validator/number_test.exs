defmodule AtomemoPluginSdk.ParameterValidator.NumberTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.Number, as: PDNumber
  alias AtomemoPluginSdk.ParameterValidator.Number, as: PVNumber

  describe "validate/3" do
    test "returns ok for valid number" do
      definition = %PDNumber{type: "number", minimum: 1.0, maximum: 10.0}

      assert {:ok, 3.5} = PVNumber.validate(definition, 3.5, path: [:default])
    end

    test "returns ok for valid integer when type is integer" do
      definition = %PDNumber{type: "integer", minimum: 1.0, maximum: 10.0}

      assert {:ok, 3} = PVNumber.validate(definition, 3, path: [:default])
    end

    test "returns ok for valid float when type is float" do
      definition = %PDNumber{type: "float", minimum: 1.0, maximum: 10.0}

      assert {:ok, 3.5} = PVNumber.validate(definition, 3.5, path: [:default])
    end

    test "returns error when value is not a number" do
      definition = %PDNumber{type: "number"}

      assert {:error, %{path: :type, message: "must be a number."}} =
               PVNumber.validate(definition, "1", path: [:default])
    end

    test "returns error when integer type gets non-integer number" do
      definition = %PDNumber{type: "integer"}

      assert {:error, %{path: :type, message: "must be an integer."}} =
               PVNumber.validate(definition, 1.5, path: [:default])
    end

    test "returns error when float type gets integer" do
      definition = %PDNumber{type: "float"}

      assert {:error, %{path: :type, message: "must be a float."}} =
               PVNumber.validate(definition, 1, path: [:default])
    end

    test "returns error when value is lower than minimum" do
      definition = %PDNumber{type: "number", minimum: 2.0}

      assert {:error, %{path: :min, message: "should be greater than or equal to 2.0"}} =
               PVNumber.validate(definition, 1.5, path: [:default])
    end

    test "returns error when value is greater than maximum" do
      definition = %PDNumber{type: "number", maximum: 3.0}

      assert {:error, %{path: :max, message: "should be less than or equal to 3.0"}} =
               PVNumber.validate(definition, 3.5, path: [:default])
    end
  end
end
