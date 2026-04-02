defmodule AtomemoPluginSdk.ParameterCodec.DiscriminatedUnionTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec
  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.Array, as: PDArray
  alias AtomemoPluginSdk.ParameterDefinition.DiscriminatedUnion, as: PDDiscriminatedUnion
  alias AtomemoPluginSdk.ParameterDefinition.EncryptedString, as: PDEncryptedString
  alias AtomemoPluginSdk.ParameterDefinition.Number, as: PDNumber
  alias AtomemoPluginSdk.ParameterDefinition.Object, as: PDObject
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterError.Entry

  describe "cast/2" do
    test "returns error when value is not a map" do
      definition = %PDDiscriminatedUnion{name: "du", discriminator: "kind", any_of: []}

      assert {:error, [%Entry{path: [], message: "must be an object."}]} =
               Codecable.cast(definition, "invalid")
    end

    test "returns error when discriminator field is missing" do
      definition = build_definition()

      assert {:error, [%Entry{path: ["kind"], message: "is required."}]} =
               Codecable.cast(definition, %{"content" => "hello"})
    end

    test "returns error when no branch matches discriminator" do
      definition = build_definition()

      assert {:error, [%Entry{path: ["kind"], message: message}]} =
               Codecable.cast(definition, %{"kind" => "unknown"})

      assert message == "no matching definition found for discriminated union."
    end

    test "casts value with matched text branch" do
      definition = build_definition()

      assert {:ok, %{"kind" => "text", "content" => "hello"}} =
               Codecable.cast(definition, %{"kind" => "text", "content" => "hello"})
    end

    test "casts value with matched number branch" do
      definition = build_definition()

      assert {:ok, %{"kind" => "number", "value" => 42}} =
               Codecable.cast(definition, %{"kind" => "number", "value" => 42})
    end

    test "returns nested property errors from matched branch" do
      definition = build_definition()

      assert {:error, entries} =
               Codecable.cast(definition, %{"kind" => "text"})

      assert [%Entry{path: ["content"], message: "is required."}] = entries
    end
  end

  describe "nested path prefix - discriminated_union in object" do
    test "object wraps DU errors with property prefix" do
      definition = %PDObject{
        properties: [
          %PDDiscriminatedUnion{
            name: "payload",
            discriminator: "kind",
            any_of: [
              %PDObject{
                properties: [
                  %PDString{name: "kind", constant: "text"},
                  %PDString{name: "content", required: true}
                ]
              }
            ]
          }
        ]
      }

      assert {:error, %Error{errors: errors}} =
               ParameterCodec.cast(definition, %{"payload" => %{"kind" => "text"}})

      assert [%Entry{path: ["payload", "content"]}] = errors
    end
  end

  describe "nested path prefix - array -> discriminated_union -> object" do
    test "array wraps DU errors with index prefix" do
      definition = %PDArray{
        items: %PDDiscriminatedUnion{
          discriminator: "kind",
          any_of: [
            %PDObject{
              properties: [
                %PDString{name: "kind", constant: "text"},
                %PDString{name: "content", required: true}
              ]
            }
          ]
        }
      }

      assert {:error, %Error{errors: errors}} =
               ParameterCodec.cast(definition, [%{"kind" => "text"}])

      assert [%Entry{path: [0, "content"]}] = errors
    end

    test "multi-level: object -> array -> discriminated_union -> object" do
      definition = %PDObject{
        properties: [
          %PDArray{
            name: "items",
            items: %PDDiscriminatedUnion{
              discriminator: "kind",
              any_of: [
                %PDObject{
                  properties: [
                    %PDString{name: "kind", constant: "text"},
                    %PDString{name: "content", required: true}
                  ]
                }
              ]
            }
          }
        ]
      }

      assert {:error, %Error{errors: errors}} =
               ParameterCodec.cast(definition, %{"items" => [%{"kind" => "text"}]})

      assert [%Entry{path: ["items", 0, "content"]}] = errors
    end

    test "multiple array items with DU errors" do
      definition = %PDArray{
        items: %PDDiscriminatedUnion{
          discriminator: "kind",
          any_of: [
            %PDObject{
              properties: [
                %PDString{name: "kind", constant: "text"},
                %PDString{name: "content", required: true}
              ]
            },
            %PDObject{
              properties: [
                %PDString{name: "kind", constant: "number"},
                %PDNumber{name: "value", required: true, type: "number", maximum: 100}
              ]
            }
          ]
        }
      }

      value = [
        %{"kind" => "text"},
        %{"kind" => "number", "value" => 150}
      ]

      assert {:error, %Error{errors: errors}} = ParameterCodec.cast(definition, value)

      sorted = Enum.sort_by(errors, & &1.path)

      assert [
               %Entry{path: [0, "content"], message: "is required."},
               %Entry{path: [1, "value"]}
             ] = sorted
    end
  end

  describe "cast_for_default/2" do
    test "delegates to cast for valid discriminated union default" do
      definition = build_definition()

      assert {:ok, %{"kind" => "text", "content" => "hello"}} =
               Codecable.cast_for_default(definition, %{
                 "kind" => "text",
                 "content" => "hello"
               })
    end

    test "returns discriminator error when no branch matches default" do
      definition = build_definition()

      assert {:error,
              [
                %Entry{
                  path: ["kind"],
                  message: "no matching definition found for discriminated union."
                }
              ]} =
               Codecable.cast_for_default(definition, %{"kind" => "unknown"})
    end
  end

  describe "integration via ParameterCodec.cast/3 - opts propagation" do
    test "propagates encrypted_string_caster to matched branch codec" do
      definition = secret_definition()
      caster = fn value -> {:ok, "ENC(" <> value <> ")"} end

      assert {:ok, %{"kind" => "secret", "secret" => "ENC(payload)"}} =
               ParameterCodec.cast(definition, %{"kind" => "secret", "secret" => "payload"},
                 encrypted_string_caster: caster
               )
    end

    test "keeps prefix single-applied while still propagating non-prefix opts" do
      definition = secret_definition()
      caster = fn _value -> {:error, "invalid encrypted value"} end

      assert {:error,
              %Error{
                errors: [%Entry{path: ["payload", "secret"], message: "invalid encrypted value"}]
              }} =
               ParameterCodec.cast(definition, %{"kind" => "secret", "secret" => "payload"},
                 prefix: "payload",
                 encrypted_string_caster: caster
               )
    end
  end

  defp build_definition do
    %PDDiscriminatedUnion{
      discriminator: "kind",
      any_of: [
        %PDObject{
          properties: [
            %PDString{name: "kind", constant: "text"},
            %PDString{name: "content", required: true}
          ]
        },
        %PDObject{
          properties: [
            %PDString{name: "kind", constant: "number"},
            %PDNumber{name: "value", required: true, type: "number", maximum: 100}
          ]
        }
      ]
    }
  end

  defp secret_definition do
    %PDDiscriminatedUnion{
      discriminator: "kind",
      any_of: [
        %PDObject{
          properties: [
            %PDString{name: "kind", constant: "secret"},
            %PDEncryptedString{name: "secret", required: true}
          ]
        }
      ]
    }
  end
end
