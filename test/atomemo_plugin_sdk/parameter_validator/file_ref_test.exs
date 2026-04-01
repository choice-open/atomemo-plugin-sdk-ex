defmodule AtomemoPluginSdk.ParameterValidator.FileRefTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.FileRef
  alias AtomemoPluginSdk.ParameterDefinition.FileRef, as: PDFileRef
  alias AtomemoPluginSdk.ParameterValidator.FileRef, as: PVFileRef

  describe "validate_default/1" do
    test "accepts mem FileRef struct for default" do
      file_ref = %FileRef{source: :mem, content: "abc"}
      definition = %PDFileRef{type: "file_ref", default: file_ref}

      assert {:ok, ^file_ref} =
               PVFileRef.validate(definition, file_ref, source: :plugin)
    end

    test "rejects oss FileRef struct for default" do
      file_ref = %FileRef{source: :oss, res_key: "foo/bar"}

      definition = %PDFileRef{
        type: "file_ref",
        default: file_ref
      }

      assert {:error, %{path: :source, message: message}} =
               PVFileRef.validate(definition, file_ref, source: :plugin)

      assert message =~ "only expected mem FileRef struct"
    end

    test "rejects non-struct default value" do
      file_ref = %{"__type__" => "file_ref", "source" => "oss", "res_key" => "bucket/a.txt"}
      definition = %PDFileRef{type: "file_ref", default: file_ref}

      assert {:error, %{path: :type, message: message}} =
               PVFileRef.validate(definition, file_ref, source: :plugin)

      assert message ==
               "Invalid default value for file_ref parameter definition: expected mem FileRef struct."
    end
  end

  describe "runtime source validation in FileRef validator" do
    test "accepts websocket map payload" do
      opts = [source: :runtime_input]

      payload = %{"__type__" => "file_ref", "source" => "oss", "res_key" => "bucket/a.txt"}

      assert {:ok, %FileRef{source: :oss, res_key: "bucket/a.txt"}} =
               PVFileRef.validate(%PDFileRef{type: "file_ref"}, payload, opts)
    end

    test "returns changeset-based error for invalid websocket payload" do
      opts = [source: :input]

      assert {:error, [issue]} =
               PVFileRef.validate(%PDFileRef{type: "file_ref"}, %{"__type__" => "file_ref"}, opts)

      assert issue.path == [:source]
      assert issue.message == "can't be blank"
    end

    test "returns type error when runtime value is not a map/object" do
      opts = [source: :input]

      assert {:error, %{path: :type, message: message}} =
               PVFileRef.validate(%PDFileRef{type: "file_ref"}, 1, opts)

      assert message =~ "must be a encoded file ref json payload"
    end

    test "returns type error when runtime value contains no __type__" do
      opts = [source: :input]
      file_ref = %{"source" => "oss", "res_key" => "bucket/a.txt"}

      assert {:error, %{path: :type, message: message}} =
               PVFileRef.validate(%PDFileRef{type: "file_ref"}, file_ref, opts)

      assert message =~ "must be a encoded file ref json payload"
    end
  end
end
