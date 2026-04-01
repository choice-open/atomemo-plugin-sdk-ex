defmodule AtomemoPluginSdk.ParameterValidator.BaseTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterValidator.Base

  describe "validate/3 - required" do
    test "returns error when required is true and value is nil" do
      definition = %PDString{required: true}

      assert {:error, %{path: :required, message: "is required."}} =
               Base.validate(definition, nil, [])
    end

    test "returns ok when required is true and value is present" do
      definition = %PDString{required: true}

      assert {:ok, "hello"} = Base.validate(definition, "hello", [])
    end

    test "returns ok when required is false and value is nil" do
      definition = %PDString{required: false}

      assert {:ok, nil} = Base.validate(definition, nil, [])
    end
  end

  describe "validate/3 - constant" do
    test "returns ok when value matches constant" do
      definition = %PDString{constant: "fixed"}

      assert {:ok, "fixed"} = Base.validate(definition, "fixed", [])
    end

    test "returns error when value does not match constant" do
      definition = %PDString{constant: "fixed"}

      assert {:error, %{path: :constant, message: "must be a constant value."}} =
               Base.validate(definition, "other", [])
    end

    test "returns ok when constant is nil (no constraint)" do
      definition = %PDString{}

      assert {:ok, "anything"} = Base.validate(definition, "anything", [])
    end

    test "returns ok when value is nil and required is false" do
      definition = %PDString{required: false, constant: "fixed"}

      assert {:ok, nil} = Base.validate(definition, nil, [])
    end
  end

  describe "validate/3 - enum" do
    test "returns ok when value is in enum list" do
      definition = %PDString{enum: ["a", "b", "c"]}

      assert {:ok, "b"} = Base.validate(definition, "b", [])
    end

    test "returns error when value is not in enum list" do
      definition = %PDString{enum: ["a", "b", "c"]}

      assert {:error, %{path: :enum, message: "is not an allowed value."}} =
               Base.validate(definition, "d", [])
    end

    test "returns ok when enum is nil (no constraint)" do
      definition = %PDString{}

      assert {:ok, "anything"} = Base.validate(definition, "anything", [])
    end

    test "returns ok when value is nil and required is false" do
      definition = %PDString{required: false, enum: ["a", "b", "c"]}

      assert {:ok, nil} = Base.validate(definition, nil, [])
    end
  end

  describe "validate/3 - combined validations" do
    test "required check runs before constant check" do
      definition = %PDString{required: true, constant: "fixed"}

      assert {:error, %{path: :required}} = Base.validate(definition, nil, [])
    end

    test "constant check runs before enum check" do
      definition = %PDString{constant: "fixed", enum: ["fixed", "other"]}

      assert {:error, %{path: :constant}} = Base.validate(definition, "other", [])
    end

    test "returns ok when all validations pass" do
      definition = %PDString{required: true, constant: "fixed", enum: ["fixed"]}

      assert {:ok, "fixed"} = Base.validate(definition, "fixed", [])
    end
  end
end
