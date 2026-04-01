defmodule AtomemoPluginSdk.ParameterValidator.ObjectTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.Object, as: PDObject
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterDefinition.Number, as: PDNumber
  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterValidator
  alias AtomemoPluginSdk.ParameterValidator.Object, as: PVObject

  describe "validate/3 - type check" do
    test "returns error when value is not a map" do
      definition = %PDObject{properties: []}

      assert {:error, %{path: :type, message: "must be an object."}} =
               PVObject.validate(definition, "not a map", [])
    end

    test "returns error when value is a list" do
      definition = %PDObject{properties: []}

      assert {:error, %{path: :type, message: "must be an object."}} =
               PVObject.validate(definition, [1, 2], [])
    end

    test "returns error when value is nil" do
      definition = %PDObject{properties: []}

      assert {:error, %{path: :type, message: "must be an object."}} =
               PVObject.validate(definition, nil, [])
    end
  end

  describe "validate/3 - properties" do
    test "returns ok with casted properties" do
      definition = %PDObject{
        properties: [
          %PDString{name: "name"},
          %PDString{name: "email"}
        ]
      }

      value = %{"name" => "Alice", "email" => "alice@test.com"}

      assert {:ok, result} = PVObject.validate(definition, value, [])
      assert result["name"] == "Alice"
      assert result["email"] == "alice@test.com"
    end

    test "returns errors with property name as path prefix" do
      definition = %PDObject{
        properties: [
          %PDString{name: "name", min_length: 3},
          %PDString{name: "email", min_length: 5}
        ]
      }

      value = %{"name" => "ab", "email" => "a@b"}

      assert {:error, issues} = PVObject.validate(definition, value, [])

      sorted = Enum.sort_by(issues, & &1.path)

      assert [
               %{path: ["email", :min], message: "should be at least 5 character(s)"},
               %{path: ["name", :min], message: "should be at least 3 character(s)"}
             ] = sorted
    end

    test "validates required property with nil value" do
      definition = %PDObject{
        properties: [
          %PDString{name: "name", required: true}
        ]
      }

      value = %{}

      assert {:error, issues} = PVObject.validate(definition, value, [])

      assert [%{path: ["name", :required], message: "is required."}] = issues
    end

    test "applies default value for missing property" do
      definition = %PDObject{
        properties: [
          %PDString{name: "role", default: "user"}
        ]
      }

      value = %{}

      assert {:ok, result} = PVObject.validate(definition, value, [])
      assert result["role"] == "user"
    end
  end

  describe "validate/3 - additional_properties" do
    test "passes through extra keys when additional_properties is nil" do
      definition = %PDObject{
        properties: [%PDString{name: "name"}],
        additional_properties: nil
      }

      value = %{"name" => "Alice", "extra" => "value", "another" => 123}

      assert {:ok, result} = PVObject.validate(definition, value, [])
      assert result["name"] == "Alice"
      assert result["extra"] == "value"
      assert result["another"] == 123
    end

    test "validates extra keys against additional_properties definition" do
      definition = %PDObject{
        properties: [%PDString{name: "name"}],
        additional_properties: %PDNumber{type: "number"}
      }

      value = %{"name" => "Alice", "score" => 100, "rank" => 1}

      assert {:ok, result} = PVObject.validate(definition, value, [])
      assert result["name"] == "Alice"
      assert result["score"] == 100
      assert result["rank"] == 1
    end

    test "returns errors with extra key name as path prefix" do
      definition = %PDObject{
        properties: [%PDString{name: "name"}],
        additional_properties: %PDNumber{type: "number"}
      }

      value = %{"name" => "Alice", "score" => "not a number"}

      assert {:error, issues} = PVObject.validate(definition, value, [])

      assert [%{path: ["score", :type], message: "must be a number."}] = issues
    end
  end

  describe "validate/3 - nested objects" do
    test "returns errors with nested path" do
      definition = %PDObject{
        properties: [
          %PDObject{
            name: "address",
            properties: [
              %PDString{name: "city", required: true}
            ]
          }
        ]
      }

      value = %{"address" => %{}}

      assert {:error, %Error{issues: issues}} = ParameterValidator.cast(definition, value)

      assert [%{path: ["address", "city", :required]}] = issues
    end
  end

  describe "validate/3 - properties error short-circuits additional_properties" do
    test "returns only property errors when properties fail" do
      definition = %PDObject{
        properties: [
          %PDString{name: "name", min_length: 3}
        ],
        additional_properties: %PDNumber{type: "number"}
      }

      value = %{"name" => "ab", "score" => "bad"}

      assert {:error, issues} = PVObject.validate(definition, value, [])

      paths = Enum.map(issues, & &1.path)
      assert ["name", :min] in paths
      refute ["score", :type] in paths
    end

    test "validates additional_properties when properties pass" do
      definition = %PDObject{
        properties: [
          %PDString{name: "name"}
        ],
        additional_properties: %PDNumber{type: "number"}
      }

      value = %{"name" => "Alice", "score" => "bad"}

      assert {:error, issues} = PVObject.validate(definition, value, [])

      assert [%{path: ["score", :type]}] = issues
    end
  end
end
