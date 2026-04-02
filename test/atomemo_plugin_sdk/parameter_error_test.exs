defmodule AtomemoPluginSdk.ParameterErrorTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.FileRef
  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterError.Entry

  describe "Entry.new/2 - string message" do
    test "returns a list with one entry" do
      assert [%Entry{path: [], message: "invalid"}] = Entry.new("invalid")
    end

    test "normalizes atom path into string" do
      assert [%Entry{path: ["type"], message: "invalid"}] = Entry.new("invalid", path: :type)
    end

    test "normalizes list path with atoms and integers" do
      assert [%Entry{path: [0, "min"], message: "too short"}] =
               Entry.new("too short", path: [0, :min])
    end

    test "string path is preserved" do
      assert [%Entry{path: ["field"], message: "bad"}] = Entry.new("bad", path: "field")
    end

    test "nil path defaults to empty list" do
      assert [%Entry{path: [], message: "fail"}] = Entry.new("fail", path: nil)
    end

    test "prepends prefix to path" do
      assert [%Entry{path: ["items", 0, "min"], message: "too short"}] =
               Entry.new("too short", path: [0, :min], prefix: :items)
    end

    test "prepends list prefix to path" do
      assert [%Entry{path: ["payload", "items", 1, "type"], message: "invalid"}] =
               Entry.new("invalid", path: [1, :type], prefix: ["payload", "items"])
    end
  end

  describe "Entry.new/2 - changeset" do
    test "extracts errors from changeset" do
      changeset = %FileRef{} |> FileRef.changeset(%{})

      entries = Entry.new(changeset)

      assert [%Entry{path: ["source"], message: "can't be blank"}] = entries
    end

    test "applies prefix to changeset errors" do
      changeset = %FileRef{} |> FileRef.changeset(%{})

      entries = Entry.new(changeset, prefix: "file")

      assert [%Entry{path: ["file", "source"], message: "can't be blank"}] = entries
    end
  end

  describe "Entry.normalize_path/1" do
    test "normalizes atoms to strings" do
      assert ["foo", "bar"] = Entry.normalize_path([:foo, :bar])
    end

    test "preserves integers" do
      assert [0, "field"] = Entry.normalize_path([0, :field])
    end

    test "wraps scalar in list" do
      assert ["field"] = Entry.normalize_path(:field)
      assert [42] = Entry.normalize_path(42)
    end
  end

  describe "Error.new/1" do
    test "stores multiple entries" do
      entries = [
        %Entry{path: ["default"], message: "must be a string."},
        %Entry{path: ["default", "name"], message: "too short"}
      ]

      error = Error.new(entries)

      assert error.errors == entries
    end

    test "stores empty list" do
      error = Error.new([])

      assert error.errors == []
    end
  end

  describe "Error.new/2 - prefix" do
    test "prepends integer prefix to all entries" do
      entries = [
        %Entry{path: ["type"], message: "must be a string."},
        %Entry{path: ["min"], message: "too short"}
      ]

      error = Error.new(entries, prefix: 2)

      assert [
               %Entry{path: [2, "type"]},
               %Entry{path: [2, "min"]}
             ] = error.errors
    end

    test "prepends atom prefix to all entries" do
      entries = [%Entry{path: ["type"], message: "must be a string."}]

      error = Error.new(entries, prefix: :items)

      assert [%Entry{path: ["items", "type"]}] = error.errors
    end

    test "prepends string prefix" do
      entries = [%Entry{path: ["type"], message: "bad"}]

      error = Error.new(entries, prefix: "field")

      assert [%Entry{path: ["field", "type"]}] = error.errors
    end

    test "does not modify entries when prefix is empty list" do
      entries = [%Entry{path: ["type"], message: "must be a string."}]

      error = Error.new(entries, prefix: [])

      assert [%Entry{path: ["type"]}] = error.errors
    end

    test "does not modify entries when prefix is not provided" do
      entries = [%Entry{path: ["type"], message: "must be a string."}]

      error = Error.new(entries)

      assert [%Entry{path: ["type"]}] = error.errors
    end
  end

  describe "message/1" do
    test "returns JSON-encoded entries joined by newline" do
      entries = [
        %Entry{path: ["field"], message: "is required."},
        %Entry{path: [0, "name"], message: "too short"}
      ]

      error = Error.new(entries)
      message = Exception.message(error)

      lines = String.split(message, "\n")
      assert length(lines) == 2

      assert {:ok, first} = JSON.decode(Enum.at(lines, 0))
      assert first["path"] == ["field"]
      assert first["message"] == "is required."

      assert {:ok, second} = JSON.decode(Enum.at(lines, 1))
      assert second["path"] == [0, "name"]
      assert second["message"] == "too short"
    end

    test "returns empty string for no errors" do
      error = Error.new([])

      assert Exception.message(error) == ""
    end
  end
end
