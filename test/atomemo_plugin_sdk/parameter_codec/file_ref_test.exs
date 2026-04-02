defmodule AtomemoPluginSdk.ParameterCodec.FileRefTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.FileRef
  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.FileRef, as: PDFileRef
  alias AtomemoPluginSdk.ParameterError.Entry

  describe "cast/2" do
    test "returns ok for valid file_ref map payload" do
      payload = %{"__type__" => "file_ref", "source" => "oss", "res_key" => "bucket/a.txt"}

      assert {:ok, %FileRef{source: :oss, res_key: "bucket/a.txt"}} =
               Codecable.cast(%PDFileRef{}, payload)
    end

    test "returns changeset-based errors for invalid file_ref payload" do
      assert {:error, [%Entry{} = entry]} =
               Codecable.cast(%PDFileRef{name: "file"}, %{"__type__" => "file_ref"})

      assert entry.message == "can't be blank"
    end

    test "returns error when value lacks __type__" do
      payload = %{"source" => "oss", "res_key" => "bucket/a.txt"}

      assert {:error, [%Entry{path: [], message: message}]} =
               Codecable.cast(%PDFileRef{name: "file"}, payload)

      assert message =~ "must be a encoded file ref json payload"
    end

    test "returns error when value is not a map" do
      assert {:error, [%Entry{message: message}]} =
               Codecable.cast(%PDFileRef{}, "not a map")

      assert message =~ "must be a encoded file ref json payload"
    end

    test "returns error when value is an integer" do
      assert {:error, [%Entry{path: [], message: message}]} =
               Codecable.cast(%PDFileRef{name: "file"}, 1)

      assert message =~ "must be a encoded file ref json payload"
    end
  end

  describe "cast_for_internal_default/2" do
    test "accepts mem FileRef struct" do
      file_ref = %FileRef{source: :mem, content: "abc"}

      assert {:ok, ^file_ref} =
               Codecable.cast_for_internal_default(%PDFileRef{}, file_ref)
    end

    test "rejects oss FileRef struct" do
      file_ref = %FileRef{source: :oss, res_key: "foo/bar"}

      assert {:error, [%Entry{message: message}]} =
               Codecable.cast_for_internal_default(%PDFileRef{}, file_ref)

      assert message =~ "only expected a mem FileRef struct"
    end

    test "rejects non-struct value" do
      assert {:error, [%Entry{message: "must be a %FileRef{} struct."}]} =
               Codecable.cast_for_internal_default(%PDFileRef{}, %{"source" => "mem"})
    end
  end
end
