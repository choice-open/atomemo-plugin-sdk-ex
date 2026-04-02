defmodule AtomemoPluginSdk.ParameterCodec.NumberTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.Number, as: PDNumber
  alias AtomemoPluginSdk.ParameterError.Entry

  describe "cast/2 - type check" do
    test "returns ok for valid number" do
      definition = %PDNumber{type: "number"}

      assert {:ok, 3.5} = Codecable.cast(definition, 3.5)
    end

    test "returns ok for integer when type is number" do
      definition = %PDNumber{type: "number"}

      assert {:ok, 3} = Codecable.cast(definition, 3)
    end

    test "returns error when value is not a number" do
      definition = %PDNumber{type: "number", name: "field"}

      assert {:error, [%Entry{path: [], message: "must be a number."}]} =
               Codecable.cast(definition, "1")
    end

    test "returns error when integer type gets float" do
      definition = %PDNumber{type: "integer", name: "field"}

      assert {:error, [%Entry{path: [], message: "must be an integer."}]} =
               Codecable.cast(definition, 1.5)
    end

    test "returns ok for valid integer when type is integer" do
      definition = %PDNumber{type: "integer"}

      assert {:ok, 3} = Codecable.cast(definition, 3)
    end

    test "returns error when float type gets integer" do
      definition = %PDNumber{type: "float", name: "field"}

      assert {:error, [%Entry{path: [], message: "must be a float."}]} =
               Codecable.cast(definition, 1)
    end

    test "returns ok for valid float when type is float" do
      definition = %PDNumber{type: "float"}

      assert {:ok, 3.5} = Codecable.cast(definition, 3.5)
    end
  end

  describe "cast/2 - range check" do
    test "returns error when value is below minimum" do
      definition = %PDNumber{type: "number", name: "field", minimum: 2.0}

      assert {:error, [%Entry{path: [], message: message}]} =
               Codecable.cast(definition, 1.5)

      assert message == "should be greater than or equal to 2.0"
    end

    test "returns ok when value equals minimum" do
      definition = %PDNumber{type: "number", minimum: 2.0}

      assert {:ok, 2.0} = Codecable.cast(definition, 2.0)
    end

    test "returns error when value exceeds maximum" do
      definition = %PDNumber{type: "number", name: "field", maximum: 3.0}

      assert {:error, [%Entry{path: [], message: message}]} =
               Codecable.cast(definition, 3.5)

      assert message == "should be less than or equal to 3.0"
    end

    test "returns ok when value equals maximum" do
      definition = %PDNumber{type: "number", maximum: 3.0}

      assert {:ok, 3.0} = Codecable.cast(definition, 3.0)
    end

    test "type check runs before range check" do
      definition = %PDNumber{type: "number", name: "f", minimum: 0}

      assert {:error, [%Entry{message: "must be a number."}]} =
               Codecable.cast(definition, "abc")
    end

    test "supports negative minimum boundary" do
      definition = %PDNumber{type: "number", minimum: -5.0}

      assert {:ok, -5.0} = Codecable.cast(definition, -5.0)

      assert {:error, [%Entry{message: "should be greater than or equal to -5.0"}]} =
               Codecable.cast(definition, -5.1)
    end

    test "supports negative maximum boundary" do
      definition = %PDNumber{type: "number", maximum: -1.0}

      assert {:ok, -1.0} = Codecable.cast(definition, -1.0)

      assert {:error, [%Entry{message: "should be less than or equal to -1.0"}]} =
               Codecable.cast(definition, 0.0)
    end
  end

  describe "cast_for_default/2" do
    test "delegates to cast for valid default" do
      definition = %PDNumber{type: "integer", minimum: 0}

      assert {:ok, 3} = Codecable.cast_for_default(definition, 3)
    end

    test "returns range validation errors for invalid default" do
      definition = %PDNumber{type: "integer", minimum: 0}

      assert {:error, [%Entry{message: "should be greater than or equal to 0"}]} =
               Codecable.cast_for_default(definition, -1)
    end
  end
end
