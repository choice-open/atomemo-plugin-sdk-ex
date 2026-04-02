defmodule AtomemoPluginSdk.ParameterDefinition.BaseTest do
  use ExUnit.Case, async: true

  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.FileRef
  alias AtomemoPluginSdk.ParameterDefinition.CredentialId, as: PDCredentialId
  alias AtomemoPluginSdk.ParameterDefinition.FileRef, as: PDFileRef
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString

  describe "__using__/1" do
    test "raises on non-boolean allow_default option" do
      module_name = "InvalidAllowDefault#{System.unique_integer([:positive])}"

      code = """
      defmodule #{module_name} do
        use Ecto.Schema
        use AtomemoPluginSdk.ParameterDefinition.Base, allow_default: \"false\"

        @primary_key false
        embedded_schema do
          base_schema()
          field :type, :string, default: \"string\"
        end

      end
      """

      assert_raise ArgumentError, ~r/invalid :allow_default option/, fn ->
        Code.compile_string(code)
      end
    end

    test "raises when no Codecable protocol implementation exists" do
      module_name = "MissingCodec#{System.unique_integer([:positive])}"

      code = """
      defmodule AtomemoPluginSdk.ParameterDefinition.#{module_name} do
        use Ecto.Schema
        use AtomemoPluginSdk.ParameterDefinition.Base

        @primary_key false
        embedded_schema do
          base_schema()
          field :type, :string, default: \"string\"
        end
      end
      """

      assert_raise Protocol.UndefinedError, fn ->
        Code.compile_string(code)
      end
    end
  end

  describe "validate_default_if_needed/1" do
    test "normalizes struct default into encoded map for atom keys" do
      changeset =
        PDFileRef.changeset(%PDFileRef{}, %{
          type: "file_ref",
          name: "file",
          default: %FileRef{source: :mem, content: "abc"}
        })

      assert changeset.valid?
      assert changeset.changes.default["__type__"] == "file_ref"
      assert changeset.changes.default["source"] == "mem"
      assert changeset.changes.default["content"] == "YWJj"
    end

    test "normalizes struct default into encoded map for string keys" do
      changeset =
        PDFileRef.changeset(%PDFileRef{}, %{
          "type" => "file_ref",
          "name" => "file",
          "default" => %FileRef{source: :mem, content: "abc"}
        })

      assert changeset.valid?
      assert changeset.changes.default["__type__"] == "file_ref"
      assert changeset.changes.default["source"] == "mem"
      assert changeset.changes.default["content"] == "YWJj"
    end

    test "skips validation when changeset is invalid" do
      changeset = PDString.changeset(%PDString{}, %{type: nil, default: "bad"})

      refute changeset.valid?
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "skips validation when default is nil" do
      changeset =
        PDCredentialId.changeset(%PDCredentialId{}, %{
          type: "credential_id",
          credential_name: "test"
        })

      assert changeset.valid?
      assert errors_on(changeset) == %{}
    end

    test "passes validation when default is valid" do
      changeset = PDString.changeset(%PDString{}, %{type: "string", default: "hello"})

      assert changeset.valid?
    end

    test "adds error when default violates codec constraints" do
      changeset =
        PDString.changeset(%PDString{}, %{type: "string", min_length: 10, default: "short"})

      refute changeset.valid?
      assert %{default: [_message]} = errors_on(changeset)
    end

    test "adds error when default is not allowed for type" do
      changeset =
        PDCredentialId.changeset(%PDCredentialId{}, %{
          type: "credential_id",
          credential_name: "test",
          default: "secret"
        })

      refute changeset.valid?
      assert %{default: [_message]} = errors_on(changeset)
    end
  end
end
