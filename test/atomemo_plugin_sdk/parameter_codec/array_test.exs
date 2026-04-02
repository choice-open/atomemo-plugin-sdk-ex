defmodule AtomemoPluginSdk.ParameterCodec.ArrayTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec
  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.Array, as: PDArray
  alias AtomemoPluginSdk.ParameterDefinition.Number, as: PDNumber
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterError.Entry

  describe "cast/2 - type check" do
    test "returns error when value is not a list" do
      definition = %PDArray{name: "arr"}

      assert {:error, [%Entry{path: [], message: "must be an array (list)."}]} =
               Codecable.cast(definition, "not a list")
    end

    test "returns error when value is a map" do
      definition = %PDArray{name: "arr"}

      assert {:error, [%Entry{path: [], message: "must be an array (list)."}]} =
               Codecable.cast(definition, %{})
    end
  end

  describe "cast/2 - max_items" do
    test "returns ok when list length equals max_items" do
      definition = %PDArray{max_items: 3}

      assert {:ok, [1, 2, 3]} = Codecable.cast(definition, [1, 2, 3])
    end

    test "returns error when list length exceeds max_items" do
      definition = %PDArray{name: "arr", max_items: 2}

      assert {:error, [%Entry{path: [], message: "must have at most 2 items."}]} =
               Codecable.cast(definition, [1, 2, 3])
    end
  end

  describe "cast/2 - min_items" do
    test "returns ok when list length equals min_items" do
      definition = %PDArray{min_items: 2}

      assert {:ok, [1, 2]} = Codecable.cast(definition, [1, 2])
    end

    test "returns error when list length is less than min_items" do
      definition = %PDArray{name: "arr", min_items: 3}

      assert {:error, [%Entry{path: [], message: "must have at least 3 items."}]} =
               Codecable.cast(definition, [1, 2])
    end
  end

  describe "cast/2 - items is nil" do
    test "returns ok with original value when items is nil" do
      definition = %PDArray{}

      assert {:ok, ["a", 1, true]} = Codecable.cast(definition, ["a", 1, true])
    end
  end

  describe "cast/2 - items validation" do
    test "returns ok with casted values for valid items" do
      definition = %PDArray{items: %PDString{}}

      assert {:ok, ["hello", "world"]} = Codecable.cast(definition, ["hello", "world"])
    end

    test "returns errors with index prefix for invalid items" do
      definition = %PDArray{items: %PDString{min_length: 3}}

      assert {:error, entries} = Codecable.cast(definition, ["ab", "hello", "cd"])

      sorted = Enum.sort_by(entries, & &1.path)

      assert [
               %Entry{path: [0], message: "should be at least 3 character(s)"},
               %Entry{path: [2], message: "should be at least 3 character(s)"}
             ] = sorted
    end

    test "returns type errors with index prefix" do
      definition = %PDArray{items: %PDNumber{type: "number"}}

      assert {:error, entries} = Codecable.cast(definition, [1, "two", 3])

      assert [%Entry{path: [1], message: "must be a number."}] = entries
    end

    test "returns ok for empty list" do
      definition = %PDArray{items: %PDString{}}

      assert {:ok, []} = Codecable.cast(definition, [])
    end

    test "applies default values from item definitions" do
      definition = %PDArray{items: %PDString{default: "fallback"}}

      assert {:ok, ["hello", "fallback"]} = Codecable.cast(definition, ["hello", nil])
    end
  end

  describe "cast/2 - nested path prefix (array of arrays)" do
    test "returns errors with nested index path" do
      definition = %PDArray{
        items: %PDArray{items: %PDString{min_length: 3}}
      }

      assert {:error, entries} = Codecable.cast(definition, [["ab", "hello"], ["ok", "cd"]])

      sorted = Enum.sort_by(entries, & &1.path)

      assert [
               %Entry{path: [0, 0]},
               %Entry{path: [1, 0]},
               %Entry{path: [1, 1]}
             ] = sorted
    end

    test "distinguishes outer and inner indices correctly" do
      definition = %PDArray{
        items: %PDArray{items: %PDString{min_length: 3}}
      }

      # outer[0] = ["hello", "world"] → all valid
      # outer[1] = ["ok"] → inner[0] fails
      # outer[2] = ["abc", "no"] → inner[1] fails
      value = [["hello", "world"], ["ok"], ["abc", "no"]]

      assert {:error, entries} = Codecable.cast(definition, value)

      sorted = Enum.sort_by(entries, & &1.path)

      assert [
               %Entry{path: [1, 0]},
               %Entry{path: [2, 1]}
             ] = sorted
    end

    test "inner array's own constraint error carries outer index" do
      definition = %PDArray{
        items: %PDArray{min_items: 2, items: %PDString{}}
      }

      # outer[0] = ["hello", "world"] → valid (2 items)
      # outer[1] = ["only"] → fails min_items
      value = [["hello", "world"], ["only"]]

      assert {:error, entries} = Codecable.cast(definition, value)

      assert [%Entry{path: [1], message: "must have at least 2 items."}] = entries
    end

    test "inner array type error carries outer index" do
      definition = %PDArray{items: %PDArray{items: %PDString{}}}

      # outer[1] is not a list
      value = [["valid"], "not a list"]

      assert {:error, entries} = Codecable.cast(definition, value)

      assert [%Entry{path: [1], message: "must be an array (list)."}] = entries
    end

    test "handles three levels of nesting" do
      definition = %PDArray{
        items: %PDArray{
          items: %PDArray{items: %PDString{min_length: 3}}
        }
      }

      # [0][0][0] = "ab" → fails
      value = [[["ab"]]]

      assert {:error, entries} = Codecable.cast(definition, value)

      assert [%Entry{path: [0, 0, 0]}] = entries
    end
  end

  describe "cast/2 - combined constraints" do
    test "checks size constraints before validating items" do
      definition = %PDArray{name: "arr", max_items: 1, items: %PDString{}}

      assert {:error, [%Entry{path: []}]} = Codecable.cast(definition, [1, 2, 3])
    end

    test "returns ok when all constraints pass" do
      definition = %PDArray{min_items: 1, max_items: 3, items: %PDString{}}

      assert {:ok, ["a", "b"]} = Codecable.cast(definition, ["a", "b"])
    end
  end

  describe "cast_for_default/2" do
    test "delegates to cast for valid array default" do
      definition = %PDArray{items: %PDString{min_length: 2}}

      assert {:ok, ["hi", "ok"]} = Codecable.cast_for_default(definition, ["hi", "ok"])
    end

    test "returns nested item errors for invalid default" do
      definition = %PDArray{items: %PDString{min_length: 3}}

      assert {:error, [%Entry{path: [0], message: "should be at least 3 character(s)"}]} =
               Codecable.cast_for_default(definition, ["ab"])
    end
  end

  describe "integration via ParameterCodec.cast/3" do
    test "wraps errors in ParameterError" do
      definition = %PDArray{name: "arr", items: %PDString{min_length: 3}}

      assert {:error, %Error{errors: [%Entry{path: [0]}]}} =
               ParameterCodec.cast(definition, ["ab"])
    end

    test "applies prefix to nested item errors" do
      definition = %PDArray{items: %PDString{min_length: 3}}

      assert {:error, %Error{errors: [%Entry{path: ["items", 0]}]}} =
               ParameterCodec.cast(definition, ["ab"], prefix: "items")
    end
  end
end
