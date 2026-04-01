defmodule AtomemoPluginSdk.ParameterValidator.ArrayTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.Array, as: PDArray
  alias AtomemoPluginSdk.ParameterDefinition.String, as: PDString
  alias AtomemoPluginSdk.ParameterDefinition.Number, as: PDNumber
  alias AtomemoPluginSdk.ParameterValidator.Array, as: PVArray

  describe "validate/3 - type check" do
    test "returns error when value is not a list" do
      definition = %PDArray{}

      assert {:error, %{path: :type, message: "must be an array (list)."}} =
               PVArray.validate(definition, "not a list", [])
    end

    test "returns error when value is a map" do
      definition = %PDArray{}

      assert {:error, %{path: :type, message: "must be an array (list)."}} =
               PVArray.validate(definition, %{}, [])
    end
  end

  describe "validate/3 - max_items" do
    test "returns ok when list length equals max_items" do
      definition = %PDArray{max_items: 3}

      assert {:ok, [1, 2, 3]} = PVArray.validate(definition, [1, 2, 3], [])
    end

    test "returns error when list length exceeds max_items" do
      definition = %PDArray{max_items: 2}

      assert {:error, %{path: :max_items, message: "must have at most 2 items."}} =
               PVArray.validate(definition, [1, 2, 3], [])
    end
  end

  describe "validate/3 - min_items" do
    test "returns ok when list length equals min_items" do
      definition = %PDArray{min_items: 2}

      assert {:ok, [1, 2]} = PVArray.validate(definition, [1, 2], [])
    end

    test "returns error when list length is less than min_items" do
      definition = %PDArray{min_items: 3}

      assert {:error, %{path: :min_items, message: "must have at least 3 items."}} =
               PVArray.validate(definition, [1, 2], [])
    end
  end

  describe "validate/3 - items is nil" do
    test "returns ok with original value when items is nil" do
      definition = %PDArray{}

      assert {:ok, ["a", 1, true]} = PVArray.validate(definition, ["a", 1, true], [])
    end
  end

  describe "validate/3 - items validation" do
    test "returns ok with casted values for valid items" do
      definition = %PDArray{items: %PDString{}}

      assert {:ok, ["hello", "world"]} = PVArray.validate(definition, ["hello", "world"], [])
    end

    test "returns errors with index path for invalid items" do
      definition = %PDArray{items: %PDString{min_length: 3}}

      assert {:error, issues} = PVArray.validate(definition, ["ab", "hello", "cd"], [])

      assert [
               %{path: [0, :min], message: "should be at least 3 character(s)"},
               %{path: [2, :min], message: "should be at least 3 character(s)"}
             ] = Enum.sort_by(issues, & &1.path)
    end

    test "returns type errors with index path" do
      definition = %PDArray{items: %PDNumber{type: "number"}}

      assert {:error, issues} = PVArray.validate(definition, [1, "two", 3], [])

      assert [%{path: [1, :type], message: "must be a number."}] = issues
    end

    test "returns ok for empty list" do
      definition = %PDArray{items: %PDString{}}

      assert {:ok, []} = PVArray.validate(definition, [], [])
    end

    test "applies default values from item definitions" do
      definition = %PDArray{items: %PDString{default: "fallback"}}

      assert {:ok, ["hello", "fallback"]} = PVArray.validate(definition, ["hello", nil], [])
    end
  end

  describe "validate/3 - nested array" do
    test "returns errors with nested index path for array of arrays" do
      definition = %PDArray{
        items: %PDArray{
          items: %PDString{min_length: 3}
        }
      }

      assert {:error, issues} = PVArray.validate(definition, [["ab", "hello"], ["ok", "cd"]], [])

      sorted = Enum.sort_by(issues, & &1.path)

      assert [
               %{path: [0, 0, :min]},
               %{path: [1, 0, :min]},
               %{path: [1, 1, :min]}
             ] = sorted
    end

    test "distinguishes outer and inner indices correctly" do
      definition = %PDArray{
        items: %PDArray{
          items: %PDString{min_length: 3}
        }
      }

      # outer[0] = ["hello", "world"] → all valid
      # outer[1] = ["ok"] → inner[0] fails
      # outer[2] = ["abc", "no"] → inner[1] fails
      value = [["hello", "world"], ["ok"], ["abc", "no"]]

      assert {:error, issues} = PVArray.validate(definition, value, [])

      sorted = Enum.sort_by(issues, & &1.path)

      assert [
               %{path: [1, 0, :min]},
               %{path: [2, 1, :min]}
             ] = sorted
    end

    test "inner array's own constraint error carries outer index" do
      definition = %PDArray{
        items: %PDArray{
          min_items: 2,
          items: %PDString{}
        }
      }

      # outer[0] = ["hello", "world"] → valid (2 items >= min_items 2)
      # outer[1] = ["only"] → inner array min_items fails (1 < 2)
      value = [["hello", "world"], ["only"]]

      assert {:error, issues} = PVArray.validate(definition, value, [])

      assert [%{path: [1, :min_items], message: "must have at least 2 items."}] = issues
    end

    test "inner array type error carries outer index" do
      definition = %PDArray{
        items: %PDArray{
          items: %PDString{}
        }
      }

      # outer[0] = ["valid"] → ok
      # outer[1] = "not a list" → inner array type check fails
      value = [["valid"], "not a list"]

      assert {:error, issues} = PVArray.validate(definition, value, [])

      assert [%{path: [1, :type], message: "must be an array (list)."}] = issues
    end

    test "inner array string item error carries both indices" do
      definition = %PDArray{
        items: %PDArray{
          items: %PDString{min_length: 3}
        }
      }

      # outer[0] = ["abc"] → valid
      # outer[1] = ["ab"] → inner[0] string min_length fails
      value = [["abc"], ["ab"]]

      assert {:error, issues} = PVArray.validate(definition, value, [])

      assert [%{path: [1, 0, :min], message: "should be at least 3 character(s)"}] = issues
    end

    test "handles three levels of nesting" do
      definition = %PDArray{
        items: %PDArray{
          items: %PDArray{
            items: %PDString{min_length: 3}
          }
        }
      }

      # [0][0][0] = "ab" → fails
      value = [[["ab"]]]

      assert {:error, issues} = PVArray.validate(definition, value, [])

      assert [%{path: [0, 0, 0, :min]}] = issues
    end
  end

  describe "validate/3 - combined constraints" do
    test "checks size constraints before validating items" do
      definition = %PDArray{max_items: 1, items: %PDString{}}

      assert {:error, %{path: :max_items}} =
               PVArray.validate(definition, [1, 2, 3], [])
    end

    test "returns ok when all constraints pass" do
      definition = %PDArray{min_items: 1, max_items: 3, items: %PDString{}}

      assert {:ok, ["a", "b"]} = PVArray.validate(definition, ["a", "b"], [])
    end
  end
end
