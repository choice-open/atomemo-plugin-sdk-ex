defmodule AtomemoPluginSdk.ParameterCodec.ObjectTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec
  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.EncryptedString, as: PDEncryptedString
  alias AtomemoPluginSdk.ParameterDefinition.Number, as: PDNumber
  alias AtomemoPluginSdk.ParameterDefinition.Object, as: PDObject
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterError.Entry

  describe "cast/2 - type check" do
    test "returns error when value is not a map" do
      definition = %PDObject{name: "obj", properties: []}

      assert {:error, [%Entry{path: [], message: "must be an object."}]} =
               Codecable.cast(definition, "not a map")
    end

    test "returns error when value is a list" do
      definition = %PDObject{name: "obj", properties: []}

      assert {:error, [%Entry{path: [], message: "must be an object."}]} =
               Codecable.cast(definition, [1, 2])
    end
  end

  describe "cast/2 - properties" do
    test "returns ok with casted properties" do
      definition = %PDObject{
        properties: [
          %PDString{name: "name"},
          %PDString{name: "email"}
        ]
      }

      value = %{"name" => "Alice", "email" => "alice@test.com"}

      assert {:ok, result} = Codecable.cast(definition, value)
      assert result["name"] == "Alice"
      assert result["email"] == "alice@test.com"
    end

    test "returns errors with property name prefix path" do
      definition = %PDObject{
        properties: [
          %PDString{name: "name", min_length: 3},
          %PDString{name: "email", min_length: 5}
        ]
      }

      value = %{"name" => "ab", "email" => "a@b"}

      assert {:error, entries} = Codecable.cast(definition, value)

      sorted = Enum.sort_by(entries, & &1.path)

      assert [
               %Entry{path: ["email"], message: "should be at least 5 character(s)"},
               %Entry{path: ["name"], message: "should be at least 3 character(s)"}
             ] = sorted
    end

    test "validates required property with nil value" do
      definition = %PDObject{
        properties: [%PDString{name: "name", required: true}]
      }

      assert {:error, entries} = Codecable.cast(definition, %{})

      assert [%Entry{path: ["name"], message: "is required."}] = entries
    end

    test "applies default value for missing property" do
      definition = %PDObject{
        properties: [%PDString{name: "role", default: "user"}]
      }

      assert {:ok, result} = Codecable.cast(definition, %{})
      assert result["role"] == "user"
    end
  end

  describe "cast/2 - additional_properties" do
    test "passes through extra keys when additional_properties is nil" do
      definition = %PDObject{
        properties: [%PDString{name: "name"}],
        additional_properties: nil
      }

      value = %{"name" => "Alice", "extra" => "value", "another" => 123}

      assert {:ok, result} = Codecable.cast(definition, value)
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

      assert {:ok, result} = Codecable.cast(definition, value)
      assert result["score"] == 100
      assert result["rank"] == 1
    end

    test "returns errors with extra key name prefix path" do
      definition = %PDObject{
        properties: [%PDString{name: "name"}],
        additional_properties: %PDNumber{type: "number"}
      }

      value = %{"name" => "Alice", "score" => "not a number"}

      assert {:error, entries} = Codecable.cast(definition, value)

      assert [%Entry{path: ["score"], message: "must be a number."}] = entries
    end
  end

  describe "cast/2 - nested objects path prefix" do
    test "returns errors with nested path via ParameterCodec.cast" do
      definition = %PDObject{
        properties: [
          %PDObject{
            name: "address",
            properties: [%PDString{name: "city", required: true}]
          }
        ]
      }

      value = %{"address" => %{}}

      assert {:error, %Error{errors: errors}} = ParameterCodec.cast(definition, value)

      assert [%Entry{path: ["address", "city"]}] = errors
    end

    test "deep nesting produces correct compound path" do
      definition = %PDObject{
        properties: [
          %PDObject{
            name: "level1",
            properties: [
              %PDObject{
                name: "level2",
                properties: [%PDString{name: "field", required: true}]
              }
            ]
          }
        ]
      }

      value = %{"level1" => %{"level2" => %{}}}

      assert {:error, %Error{errors: errors}} = ParameterCodec.cast(definition, value)

      assert [%Entry{path: ["level1", "level2", "field"]}] = errors
    end

    test "repeated key names keep full nesting depth" do
      definition = %PDObject{
        properties: [
          %PDObject{
            name: "node",
            properties: [
              %PDObject{
                name: "node",
                properties: [%PDString{name: "node", required: true}]
              }
            ]
          }
        ]
      }

      value = %{"node" => %{"node" => %{}}}

      assert {:error, %Error{errors: errors}} = ParameterCodec.cast(definition, value)

      assert [%Entry{path: ["node", "node", "node"], message: "is required."}] = errors
    end
  end

  describe "cast/2 - property error short-circuits additional_properties" do
    test "returns only property errors when properties fail" do
      definition = %PDObject{
        properties: [%PDString{name: "name", min_length: 3}],
        additional_properties: %PDNumber{type: "number"}
      }

      value = %{"name" => "ab", "score" => "bad"}

      assert {:error, entries} = Codecable.cast(definition, value)

      paths = Enum.map(entries, & &1.path)
      assert ["name"] in paths
      refute ["score"] in paths
    end

    test "validates additional_properties when properties pass" do
      definition = %PDObject{
        properties: [%PDString{name: "name"}],
        additional_properties: %PDNumber{type: "number"}
      }

      value = %{"name" => "Alice", "score" => "bad"}

      assert {:error, entries} = Codecable.cast(definition, value)

      assert [%Entry{path: ["score"]}] = entries
    end
  end

  describe "cast_for_default/2" do
    test "delegates to cast for valid object default" do
      definition = %PDObject{
        properties: [%PDString{name: "name", min_length: 2}]
      }

      assert {:ok, %{"name" => "Alice"}} =
               Codecable.cast_for_default(definition, %{"name" => "Alice"})
    end

    test "returns property-prefixed errors for invalid default" do
      definition = %PDObject{
        properties: [%PDString{name: "name", min_length: 3}]
      }

      assert {:error, [%Entry{path: ["name"], message: "should be at least 3 character(s)"}]} =
               Codecable.cast_for_default(definition, %{"name" => "ab"})
    end
  end

  describe "integration via ParameterCodec.cast/3 - opts propagation" do
    test "propagates encrypted_string_caster to property codec" do
      definition = %PDObject{
        properties: [%PDEncryptedString{name: "password"}]
      }

      caster = fn value -> {:ok, "ENC(" <> value <> ")"} end

      assert {:ok, %{"password" => "ENC(secret)"}} =
               ParameterCodec.cast(definition, %{"password" => "secret"},
                 encrypted_string_caster: caster
               )
    end

    test "propagates encrypted_string_caster to additional_properties codec" do
      definition = %PDObject{
        properties: [],
        additional_properties: %PDEncryptedString{}
      }

      caster = fn value -> {:ok, "ENC(" <> value <> ")"} end

      assert {:ok, %{"token" => "ENC(secret-token)"}} =
               ParameterCodec.cast(definition, %{"token" => "secret-token"},
                 encrypted_string_caster: caster
               )
    end

    test "keeps property path when property caster returns an error" do
      definition = %PDObject{
        properties: [%PDEncryptedString{name: "password"}]
      }

      caster = fn _value -> {:error, "invalid encrypted value"} end

      assert {:error,
              %Error{
                errors: [%Entry{path: ["password"], message: "invalid encrypted value"}]
              }} =
               ParameterCodec.cast(definition, %{"password" => "secret"},
                 encrypted_string_caster: caster
               )
    end

    test "keeps additional property key path when caster returns an error" do
      definition = %PDObject{
        properties: [],
        additional_properties: %PDEncryptedString{}
      }

      caster = fn _value -> {:error, "invalid encrypted value"} end

      assert {:error,
              %Error{errors: [%Entry{path: ["token"], message: "invalid encrypted value"}]}} =
               ParameterCodec.cast(definition, %{"token" => "secret"},
                 encrypted_string_caster: caster
               )
    end
  end
end
