defmodule AtomemoPluginSdk.FileRefTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.FileRef

  @valid_attrs %{
    "source" => "oss",
    "filename" => "test.txt",
    "extension" => "txt",
    "mime_type" => "text/plain",
    "size" => 5,
    "res_key" => "res_123",
    "remote_url" => "https://example.com/test.txt",
    "content" => Base.encode64("hello")
  }

  describe "new/1" do
    test "builds struct from valid attrs" do
      assert {:ok, %FileRef{} = ref} = FileRef.new(@valid_attrs)

      assert ref.source == :oss
      assert ref.filename == "test.txt"
      assert ref.extension == "txt"
      assert ref.mime_type == "text/plain"
      assert ref.size == 5
      assert ref.res_key == "res_123"
      assert ref.remote_url == "https://example.com/test.txt"
      assert ref.content == "hello"
    end

    test "supports :mem source and nil content/size" do
      attrs =
        @valid_attrs
        |> Map.put("source", "mem")
        |> Map.put("content", nil)
        |> Map.put("size", nil)

      assert {:ok, %FileRef{} = ref} = FileRef.new(attrs)

      assert ref.source == :mem
      assert ref.content == nil
      assert ref.size == nil
    end

    test "returns error when input is not a map" do
      assert {:error, "not a map"} = FileRef.new(:foo)
      assert {:error, "not a map"} = FileRef.new("foo")
    end

    test "requires source" do
      assert {:error, "source is required"} = FileRef.new(%{})
    end

    test "validates source" do
      assert {:error, "invalid source: \"invalid\""} =
               FileRef.new(%{"source" => "invalid"})
    end

    test "validates content must be binary when present" do
      attrs = Map.put(@valid_attrs, "content", 123)

      assert {:error, "content must be binary"} = FileRef.new(attrs)
    end

    test "validates content must be base64 when binary" do
      attrs = Map.put(@valid_attrs, "content", "not-base64")

      assert {:error, "invalid base64 content"} = FileRef.new(attrs)
    end

    test "validates optional string fields" do
      base = %{
        "source" => "oss",
        "content" => Base.encode64("x")
      }

      assert {:error, "invalid field: filename"} =
               FileRef.new(Map.put(base, "filename", 123))

      assert {:error, "invalid field: extension"} =
               FileRef.new(Map.put(base, "extension", 123))

      assert {:error, "invalid field: mime_type"} =
               FileRef.new(Map.put(base, "mime_type", 123))

      assert {:error, "invalid field: res_key"} =
               FileRef.new(Map.put(base, "res_key", 123))

      assert {:error, "invalid field: remote_url"} =
               FileRef.new(Map.put(base, "remote_url", 123))
    end

    test "validates size as integer and non-negative" do
      base = %{
        "source" => "oss",
        "content" => Base.encode64("x")
      }

      assert {:error, "size must be integer"} =
               FileRef.new(Map.put(base, "size", "10"))

      assert {:error, "size must be non-negative"} =
               FileRef.new(Map.put(base, "size", -1))
    end
  end

  describe "new!/1" do
    test "returns struct on success" do
      assert %FileRef{} = FileRef.new!(@valid_attrs)
    end

    test "raises ArgumentError on invalid input" do
      assert_raise ArgumentError, "Invalid FileRef: source is required", fn ->
        FileRef.new!(%{})
      end
    end
  end

  describe "JSON.Encoder implementation" do
    test "encodes as expected JSON shape" do
      file_ref = %FileRef{
        source: :oss,
        filename: "file.bin",
        extension: "bin",
        mime_type: "application/octet-stream",
        size: 3,
        res_key: "res_456",
        remote_url: "https://example.com/file.bin",
        content: "bin"
      }

      json =
        file_ref
        |> JSON.encode_to_iodata!()
        |> IO.iodata_to_binary()

      {:ok, decoded} = Jason.decode(json)

      assert decoded["__type__"] == "file_ref"
      assert decoded["source"] == "oss"
      assert decoded["filename"] == "file.bin"
      assert decoded["extension"] == "bin"
      assert decoded["mime_type"] == "application/octet-stream"
      assert decoded["size"] == 3
      assert decoded["res_key"] == "res_456"
      assert decoded["remote_url"] == "https://example.com/file.bin"
      assert decoded["content"] == Base.encode64("bin")
    end
  end
end

