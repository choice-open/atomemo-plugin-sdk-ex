defmodule AtomemoPluginSdk.ParameterDefinitionTest do
  use ExUnit.Case, async: true
  use AtomemoPluginSdk.ParameterDefinition

  import Ecto.Changeset
  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterDefinition.Number, as: PDNumber
  alias AtomemoPluginSdk.ParameterDefinition.Boolean, as: PDBoolean
  alias AtomemoPluginSdk.ParameterDefinition.Object, as: PDObject
  alias AtomemoPluginSdk.ParameterDefinition.Array, as: PDArray
  alias AtomemoPluginSdk.ParameterDefinition.DiscriminatedUnion, as: PDDiscriminatedUnion
  alias AtomemoPluginSdk.ParameterDefinition.CredentialId, as: PDCredentialId
  alias AtomemoPluginSdk.ParameterDefinition.EncryptedString, as: PDEncryptedString
  alias AtomemoPluginSdk.ParameterDefinition.FileRef, as: PDFileRef

  defmodule TestContainer do
    use Ecto.Schema
    use AtomemoPluginSdk.ParameterDefinition

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      parameters :parameters
    end

    def changeset(container, attrs) do
      container
      |> cast(attrs, [])
      |> cast_parameters(:parameters)
    end
  end

  describe "parameters with file_ref type" do
    test "can create container with file_ref parameter" do
      attrs = %{
        parameters: [
          %{
            type: "file_ref",
            name: "input_file",
            display_name: %{"en_US" => "Input File"}
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDFileRef{} = param] = container.parameters
      assert param.type == "file_ref"
      assert param.name == "input_file"
      assert param.display_name == %{"en_US" => "Input File"}
    end
  end

  describe "parameters with string type" do
    test "can create container with string parameter" do
      attrs = %{
        parameters: [
          %{
            type: "string",
            name: "test_param",
            display_name: %{"en_US" => "Test Parameter"}
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDString{} = param] = container.parameters
      assert param.decoder == nil
      assert param.type == "string"
      assert param.name == "test_param"
      assert param.display_name == %{"en_US" => "Test Parameter"}
    end
  end

  describe "parameters with number type" do
    test "can create container with number parameter" do
      attrs = %{
        parameters: [
          %{
            type: "number",
            name: "test_number",
            display_name: %{"en_US" => "Test Number"},
            minimum: 0.0,
            maximum: 100.0
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDNumber{} = param] = container.parameters
      assert param.decoder == nil
      assert param.type == "number"
      assert param.name == "test_number"
      assert param.display_name == %{"en_US" => "Test Number"}
      assert param.minimum == 0.0
      assert param.maximum == 100.0
    end

    test "can create container with integer type" do
      attrs = %{
        parameters: [
          %{
            type: "integer",
            name: "test_integer",
            display_name: %{"en_US" => "Test Integer"},
            minimum: 1.0,
            maximum: 10.0
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDNumber{} = param] = container.parameters
      assert param.decoder == nil
      assert param.type == "integer"
      assert param.name == "test_integer"
      assert param.display_name == %{"en_US" => "Test Integer"}
      assert param.minimum == 1.0
      assert param.maximum == 10.0
    end
  end

  describe "parameters with boolean type" do
    test "can create container with boolean parameter" do
      attrs = %{
        parameters: [
          %{
            type: "boolean",
            name: "test_boolean",
            display_name: %{"en_US" => "Test Boolean"}
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDBoolean{} = param] = container.parameters
      assert param.decoder == nil
      assert param.type == "boolean"
      assert param.name == "test_boolean"
      assert param.display_name == %{"en_US" => "Test Boolean"}
    end
  end

  describe "parameters with object type" do
    test "can create container with object parameter" do
      attrs = %{
        parameters: [
          %{
            type: "object",
            name: "test_object",
            display_name: %{"en_US" => "Test Object"},
            properties: [
              %{
                type: "string",
                name: "field1",
                display_name: %{"en_US" => "Field 1"}
              },
              %{
                type: "number",
                name: "field2",
                display_name: %{"en_US" => "Field 2"}
              }
            ],
            additional_properties: %{
              type: "string"
            }
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDObject{} = param] = container.parameters
      assert param.decoder == nil
      assert param.type == "object"
      assert param.name == "test_object"
      assert param.display_name == %{"en_US" => "Test Object"}
      assert param.additional_properties == %PDString{}
      assert length(param.properties) == 2

      [%PDString{} = prop1, %PDNumber{} = prop2] = param.properties
      assert prop1.name == "field1"
      assert prop2.name == "field2"
    end
  end

  describe "parameters with array type" do
    test "can create container with array parameter" do
      attrs = %{
        parameters: [
          %{
            type: "array",
            name: "test_array",
            display_name: %{"en_US" => "Test Array"},
            min_items: 1,
            max_items: 10,
            items: %{
              type: "string",
              name: "item",
              display_name: %{"en_US" => "Item"}
            }
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDArray{} = param] = container.parameters
      assert param.type == "array"
      assert param.name == "test_array"
      assert param.display_name == %{"en_US" => "Test Array"}
      assert param.min_items == 1
      assert param.max_items == 10

      assert %PDString{} = param.items
      assert param.items.name == "item"
    end
  end

  describe "parameters with credential_id type" do
    test "can create container with credential_id parameter" do
      attrs = %{
        parameters: [
          %{
            type: "credential_id",
            name: "test_credential",
            display_name: %{"en_US" => "Test Credential"},
            credential_name: "my_credential"
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDCredentialId{} = param] = container.parameters
      assert param.type == "credential_id"
      assert param.name == "test_credential"
      assert param.display_name == %{"en_US" => "Test Credential"}
      assert param.credential_name == "my_credential"
    end
  end

  describe "parameters with encrypted_string type" do
    test "can create container with encrypted_string parameter" do
      attrs = %{
        parameters: [
          %{
            type: "encrypted_string",
            name: "test_encrypted",
            display_name: %{"en_US" => "Test Encrypted String"}
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDEncryptedString{} = param] = container.parameters
      assert param.type == "encrypted_string"
      assert param.name == "test_encrypted"
      assert param.display_name == %{"en_US" => "Test Encrypted String"}
    end
  end

  describe "array with discriminated items" do
    test "can create array parameter with discriminated items" do
      attrs = %{
        parameters: [
          %{
            type: "array",
            name: "test_array_discriminated",
            display_name: %{"en_US" => "Test Array with Discriminated Items"},
            min_items: 1,
            max_items: 5,
            items: %{
              type: "discriminated_union",
              discriminator: "kind",
              any_of: [
                %{
                  type: "object",
                  name: "text_item",
                  properties: [
                    %{
                      type: "string",
                      name: "kind",
                      constant: "text"
                    },
                    %{
                      type: "string",
                      name: "content",
                      display_name: %{"en_US" => "Content"}
                    }
                  ]
                },
                %{
                  type: "object",
                  name: "number_item",
                  properties: [
                    %{
                      type: "string",
                      name: "kind",
                      constant: "number"
                    },
                    %{
                      type: "number",
                      name: "value",
                      display_name: %{"en_US" => "Value"}
                    }
                  ]
                }
              ]
            }
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDArray{} = param] = container.parameters
      assert param.type == "array"
      assert param.name == "test_array_discriminated"
      assert param.min_items == 1
      assert param.max_items == 5

      assert %PDDiscriminatedUnion{} = param.items
      assert param.items.discriminator == "kind"
      assert length(param.items.any_of) == 2

      [%PDObject{} = obj1, %PDObject{} = obj2] = param.items.any_of
      assert obj1.name == "text_item"
      assert obj2.name == "number_item"
    end
  end

  describe "object with discriminated properties" do
    test "can create object parameter with discriminated properties" do
      attrs = %{
        parameters: [
          %{
            type: "object",
            name: "test_object_discriminated",
            display_name: %{"en_US" => "Test Object with Discriminated Properties"},
            properties: [
              %{
                type: "discriminated_union",
                name: "foo",
                discriminator: "kind",
                any_of: [
                  %{
                    type: "object",
                    name: "text_item",
                    properties: [
                      %{
                        type: "string",
                        name: "kind",
                        constant: "text"
                      },
                      %{
                        type: "string",
                        name: "content",
                        display_name: %{"en_US" => "Content"}
                      }
                    ]
                  },
                  %{
                    type: "object",
                    name: "number_item",
                    properties: [
                      %{
                        type: "string",
                        name: "kind",
                        constant: "number"
                      },
                      %{
                        type: "number",
                        name: "content",
                        display_name: %{"en_US" => "Content"}
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDObject{} = param] = container.parameters
      assert param.type == "object"
      assert param.name == "test_object_discriminated"

      assert [%PDDiscriminatedUnion{discriminator: "kind", name: "foo"}] = param.properties

      [%PDObject{} = obj1, %PDObject{} = obj2] = hd(param.properties).any_of
      assert obj1.name == "text_item"
      assert obj2.name == "number_item"
    end
  end

  describe "parameter name uniqueness validation" do
    test "rejects duplicate parameter names" do
      attrs = %{
        parameters: [
          %{
            type: "string",
            name: "duplicate_name",
            display_name: %{"en_US" => "First Parameter"}
          },
          %{
            type: "number",
            name: "duplicate_name",
            display_name: %{"en_US" => "Second Parameter"}
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)
      refute changeset.valid?

      assert %{
               parameters: [
                 "parameter names must be unique, found duplicates: [\"duplicate_name\"]"
               ]
             } =
               errors_on(changeset)
    end

    test "allows parameters with unique names" do
      attrs = %{
        parameters: [
          %{
            type: "string",
            name: "param1",
            display_name: %{"en_US" => "Parameter 1"}
          },
          %{
            type: "number",
            name: "param2",
            display_name: %{"en_US" => "Parameter 2"}
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)
      assert changeset.valid?
    end

    test "rejects multiple duplicate names" do
      attrs = %{
        parameters: [
          %{
            type: "string",
            name: "duplicate1",
            display_name: %{"en_US" => "First"}
          },
          %{
            type: "number",
            name: "duplicate1",
            display_name: %{"en_US" => "Second"}
          },
          %{
            type: "boolean",
            name: "duplicate2",
            display_name: %{"en_US" => "Third"}
          },
          %{
            type: "string",
            name: "duplicate2",
            display_name: %{"en_US" => "Fourth"}
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)
      refute changeset.valid?

      error_message = errors_on(changeset).parameters |> List.first()
      assert error_message =~ "parameter names must be unique"
      assert error_message =~ "duplicate1"
      assert error_message =~ "duplicate2"
    end
  end

  describe "parameter with decoder" do
    test "can create container with decoder" do
      attrs = %{
        parameters: [
          %{
            decoder: "json",
            type: "number",
            name: "test_number",
            display_name: %{"en_US" => "Test Number"},
            minimum: 0.0,
            maximum: 100.0
          }
        ]
      }

      changeset = TestContainer.changeset(%TestContainer{}, attrs)

      assert changeset.valid?
      assert {:ok, container} = apply_action(changeset, :insert)
      assert length(container.parameters) == 1

      [%PDNumber{} = param] = container.parameters
      assert param.decoder == :json
      assert param.type == "number"
      assert param.name == "test_number"
      assert param.display_name == %{"en_US" => "Test Number"}
      assert param.minimum == 0.0
      assert param.maximum == 100.0
    end
  end
end
