defmodule AtomemoPluginSdk.FileRefTest do
  use ExUnit.Case, async: true

  import AtomemoPluginSdk.TestHelpers
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

  describe "hydrate_changeset/2" do
    test "casts all fields" do
      changeset = FileRef.hydrate_changeset(%FileRef{}, @valid_attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :source) == :oss
      assert Ecto.Changeset.get_field(changeset, :filename) == "test.txt"
      assert Ecto.Changeset.get_field(changeset, :extension) == "txt"
      assert Ecto.Changeset.get_field(changeset, :mime_type) == "text/plain"
      assert Ecto.Changeset.get_field(changeset, :size) == 5
      assert Ecto.Changeset.get_field(changeset, :res_key) == "res_123"
      assert Ecto.Changeset.get_field(changeset, :remote_url) == "https://example.com/test.txt"
      assert Ecto.Changeset.get_field(changeset, :content) == "hello"
    end

    test "validates required source" do
      changeset =
        FileRef.hydrate_changeset(%FileRef{}, %{
          "size" => -1
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).source
    end
  end

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
      assert ref.content == Base.encode64("hello")
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
      assert {:error, changeset} = FileRef.new(%{})
      assert "can't be blank" in errors_on(changeset).source
    end

    test "validates source" do
      assert {:error, changeset} = FileRef.new(%{"source" => "invalid"})
      assert "is invalid" in errors_on(changeset).source
    end

    test "validates content must be binary when present" do
      attrs = Map.put(@valid_attrs, "content", 123)

      assert {:error, changeset} = FileRef.new(attrs)
      assert "is invalid" in errors_on(changeset).content
    end

    test "validates content must be base64 when binary" do
      attrs = Map.put(@valid_attrs, "content", "not-base64")

      # changeset does not validate base64, so it passes
      assert {:ok, %FileRef{content: "not-base64"}} = FileRef.new(attrs)
    end

    test "validates optional string fields" do
      base = %{
        "source" => "oss",
        "content" => Base.encode64("x")
      }

      for field <- ~w(filename extension mime_type res_key remote_url) do
        assert {:error, changeset} = FileRef.new(Map.put(base, field, 123))
        assert "is invalid" in errors_on(changeset)[String.to_existing_atom(field)]
      end
    end

    test "validates size as non-negative" do
      base = %{
        "source" => "oss",
        "content" => Base.encode64("x")
      }

      # size "10" is cast to integer 10 by Ecto
      assert {:ok, %FileRef{size: 10}} = FileRef.new(Map.put(base, "size", "10"))

      assert {:error, changeset} = FileRef.new(Map.put(base, "size", -1))
      assert "must be greater than or equal to 0" in errors_on(changeset).size
    end
  end

  describe "new!/1" do
    test "returns struct on success" do
      assert %FileRef{} = FileRef.new!(@valid_attrs)
    end

    test "raises ParameterError on invalid input" do
      assert_raise AtomemoPluginSdk.ParameterError, fn ->
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
