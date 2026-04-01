defmodule AtomemoPluginSdk.ParameterValidator.DiscriminatedUnionTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.DiscriminatedUnion, as: PDDiscriminatedUnion
  alias AtomemoPluginSdk.ParameterDefinition.Array, as: PDArray
  alias AtomemoPluginSdk.ParameterDefinition.Number, as: PDNumber
  alias AtomemoPluginSdk.ParameterDefinition.Object, as: PDObject
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterValidator
  alias AtomemoPluginSdk.ParameterValidator.DiscriminatedUnion, as: PVDiscriminatedUnion

  describe "validate/3" do
    test "returns error when value is not an object" do
      definition = %PDDiscriminatedUnion{discriminator: "kind", any_of: []}

      assert {:error, %{path: :type, message: "must be an object."}} =
               PVDiscriminatedUnion.validate(definition, "invalid", [])
    end

    test "returns error when discriminator is missing" do
      definition = build_definition()

      assert {:error, %{path: "kind", message: "is required."}} =
               PVDiscriminatedUnion.validate(definition, %{"content" => "hello"}, [])
    end

    test "returns error when no branch matches discriminator" do
      definition = build_definition()

      assert {:error, %{path: "kind", message: message}} =
               PVDiscriminatedUnion.validate(definition, %{"kind" => "unknown"}, [])

      assert message == "no matching definition found for discriminated union."
    end

    test "casts object with matched string branch" do
      definition = build_definition()

      assert {:ok, %{"kind" => "text", "content" => "hello"}} =
               PVDiscriminatedUnion.validate(
                 definition,
                 %{"kind" => "text", "content" => "hello"},
                 []
               )
    end

    test "casts object with matched number branch" do
      definition = build_definition()

      assert {:ok, %{"kind" => "number", "value" => 42}} =
               PVDiscriminatedUnion.validate(definition, %{"kind" => "number", "value" => 42}, [])
    end

    test "keeps nested prefix behavior when used inside object parameter" do
      definition = build_definition()

      assert {:error, %Error{issues: issues}} =
               ParameterValidator.cast(definition, %{"kind" => "text", "value" => 110})

      assert [%{path: ["content", :required]}] = issues
    end

    test "keeps single prefix when discriminated_union is nested in object" do
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

      assert {:error, %Error{issues: issues}} =
               ParameterValidator.cast(definition, %{"payload" => %{"kind" => "text"}})

      assert [%{path: ["payload", "content", :required]}] = issues
    end

    test "keeps correct path for multi-level nesting" do
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

      assert {:error, %Error{issues: issues}} =
               ParameterValidator.cast(definition, %{"items" => [%{"kind" => "text"}]})

      assert [%{path: ["items", 0, "content", :required]}] = issues
    end

    test "keeps correct path for array -> discriminated_union -> object nesting" do
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

      assert {:error, %Error{issues: issues}} =
               ParameterValidator.cast(definition, [%{"kind" => "text"}])

      assert [%{path: [0, "content", :required]}] = issues
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
            %PDNumber{name: "value", required: true, maximum: 100}
          ]
        }
      ]
    }
  end
end
