defmodule AtomemoPluginSdk.ParameterCodec.StringTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterCodec.Codecable
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterError.Entry

  describe "cast/2" do
    test "returns ok for valid string" do
      definition = %PDString{}

      assert {:ok, "hello"} = Codecable.cast(definition, "hello")
    end

    test "returns error when value is not a string" do
      definition = %PDString{name: "field"}

      assert {:error, [%Entry{path: [], message: "must be a string."}]} =
               Codecable.cast(definition, 123)
    end

    test "returns error when value is a list" do
      definition = %PDString{name: "field"}

      assert {:error, [%Entry{path: [], message: "must be a string."}]} =
               Codecable.cast(definition, ["a"])
    end

    test "returns error when shorter than min_length" do
      definition = %PDString{name: "field", min_length: 3}

      assert {:error, [%Entry{path: [], message: message}]} =
               Codecable.cast(definition, "ab")

      assert message == "should be at least 3 character(s)"
    end

    test "returns ok when length equals min_length" do
      definition = %PDString{min_length: 3}

      assert {:ok, "abc"} = Codecable.cast(definition, "abc")
    end

    test "returns error when longer than max_length" do
      definition = %PDString{name: "field", max_length: 3}

      assert {:error, [%Entry{path: [], message: message}]} =
               Codecable.cast(definition, "toolong")

      assert message == "should be at most 3 character(s)"
    end

    test "returns ok when length equals max_length" do
      definition = %PDString{max_length: 3}

      assert {:ok, "abc"} = Codecable.cast(definition, "abc")
    end

    test "returns ok when within min and max range" do
      definition = %PDString{min_length: 1, max_length: 10}

      assert {:ok, "hello"} = Codecable.cast(definition, "hello")
    end

    test "path is empty when name is nil" do
      definition = %PDString{min_length: 5}

      assert {:error, [%Entry{path: []}]} = Codecable.cast(definition, "ab")
    end

    test "counts unicode graphemes for min_length" do
      definition = %PDString{min_length: 2}

      assert {:error, [%Entry{message: "should be at least 2 character(s)"}]} =
               Codecable.cast(definition, "你")
    end

    test "counts unicode graphemes for max_length" do
      definition = %PDString{max_length: 2}

      assert {:error, [%Entry{message: "should be at most 2 character(s)"}]} =
               Codecable.cast(definition, "你好啊")
    end
  end

  describe "cast_for_default/2" do
    test "delegates to cast" do
      definition = %PDString{min_length: 3}

      assert {:ok, "hello"} = Codecable.cast_for_default(definition, "hello")

      assert {:error, [%Entry{message: "should be at least 3 character(s)"}]} =
               Codecable.cast_for_default(definition, "ab")
    end
  end
end
