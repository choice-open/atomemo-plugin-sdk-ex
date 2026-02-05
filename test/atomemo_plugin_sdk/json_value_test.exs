defmodule AtomemoPluginSdk.JSONValueTest do
  use ExUnit.Case

  alias AtomemoPluginSdk.JSONValue

  describe "type/0" do
    test "returns :map" do
      assert JSONValue.type() == :map
    end
  end

  describe "cast/1" do
    test "accepts string" do
      assert {:ok, "hello"} = JSONValue.cast("hello")
      assert {:ok, ""} = JSONValue.cast("")
    end

    test "accepts integer" do
      assert {:ok, 123} = JSONValue.cast(123)
      assert {:ok, 0} = JSONValue.cast(0)
      assert {:ok, -42} = JSONValue.cast(-42)
    end

    test "accepts float" do
      assert {:ok, 3.14} = JSONValue.cast(3.14)
      assert {:ok, +0.0} = JSONValue.cast(0.0)
      assert {:ok, -1.5} = JSONValue.cast(-1.5)
    end

    test "accepts boolean" do
      assert {:ok, true} = JSONValue.cast(true)
      assert {:ok, false} = JSONValue.cast(false)
    end

    test "accepts nil" do
      assert {:ok, nil} = JSONValue.cast(nil)
    end

    test "accepts map" do
      value = %{"key" => "value", "number" => 42}
      assert {:ok, ^value} = JSONValue.cast(value)
    end

    test "accepts empty map" do
      assert {:ok, %{}} = JSONValue.cast(%{})
    end

    test "accepts list" do
      assert {:ok, [1, 2, 3]} = JSONValue.cast([1, 2, 3])
      assert {:ok, ["a", "b", "c"]} = JSONValue.cast(["a", "b", "c"])
      assert {:ok, []} = JSONValue.cast([])
    end

    test "accepts nested structures" do
      value = %{
        "string" => "hello",
        "number" => 42,
        "boolean" => true,
        "null" => nil,
        "array" => [1, 2, 3],
        "object" => %{"nested" => "value"}
      }

      assert {:ok, ^value} = JSONValue.cast(value)
    end

    test "rejects atom" do
      assert {:error, [message: "invalid JSON value"]} = JSONValue.cast(:atom)
    end

    test "rejects tuple" do
      assert {:error, [message: "invalid JSON value"]} = JSONValue.cast({1, 2, 3})
    end

    test "rejects pid" do
      assert {:error, [message: "invalid JSON value"]} = JSONValue.cast(self())
    end

    test "rejects map with non-string keys" do
      assert {:error, [message: "map keys must be strings"]} = JSONValue.cast(%{:atom => "value"})
      assert {:error, [message: "map keys must be strings"]} = JSONValue.cast(%{123 => "value"})
    end

    test "rejects map with invalid JSON values" do
      assert {:error, [message: "invalid JSON value"]} = JSONValue.cast(%{"key" => :atom})
      assert {:error, [message: "invalid JSON value"]} = JSONValue.cast(%{"key" => self()})
    end

    test "rejects nested map with invalid JSON values" do
      assert {:error, [message: "invalid JSON value"]} =
               JSONValue.cast(%{"nested" => %{"key" => :atom}})
    end

    test "rejects list with invalid JSON values" do
      assert {:error, [message: "invalid JSON value"]} = JSONValue.cast([1, 2, :atom])
      assert {:error, [message: "invalid JSON value"]} = JSONValue.cast(["a", self()])
    end

    test "rejects nested list with invalid JSON values" do
      assert {:error, [message: "invalid JSON value"]} =
               JSONValue.cast([[1, 2], [3, :atom]])
    end

    test "rejects map with nested invalid structures" do
      assert {:error, [message: "map keys must be strings"]} =
               JSONValue.cast(%{"valid" => %{:invalid_key => "value"}})
    end
  end

  describe "load/1" do
    test "accepts string" do
      assert {:ok, "hello"} = JSONValue.load("hello")
    end

    test "accepts integer" do
      assert {:ok, 123} = JSONValue.load(123)
    end

    test "accepts float" do
      assert {:ok, 3.14} = JSONValue.load(3.14)
    end

    test "accepts boolean" do
      assert {:ok, true} = JSONValue.load(true)
      assert {:ok, false} = JSONValue.load(false)
    end

    test "accepts nil" do
      assert {:ok, nil} = JSONValue.load(nil)
    end

    test "accepts map" do
      value = %{"key" => "value"}
      assert {:ok, ^value} = JSONValue.load(value)
    end

    test "accepts list" do
      assert {:ok, [1, 2, 3]} = JSONValue.load([1, 2, 3])
    end
  end

  describe "dump/1" do
    test "accepts string" do
      assert {:ok, "hello"} = JSONValue.dump("hello")
    end

    test "accepts integer" do
      assert {:ok, 123} = JSONValue.dump(123)
    end

    test "accepts float" do
      assert {:ok, 3.14} = JSONValue.dump(3.14)
    end

    test "accepts boolean" do
      assert {:ok, true} = JSONValue.dump(true)
      assert {:ok, false} = JSONValue.dump(false)
    end

    test "accepts nil" do
      assert {:ok, nil} = JSONValue.dump(nil)
    end

    test "accepts map" do
      value = %{"key" => "value"}
      assert {:ok, ^value} = JSONValue.dump(value)
    end

    test "accepts list" do
      assert {:ok, [1, 2, 3]} = JSONValue.dump([1, 2, 3])
    end
  end
end
