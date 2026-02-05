defmodule AtomemoPluginSdk.I18nEntryTest do
  use ExUnit.Case

  alias AtomemoPluginSdk.I18nEntry

  describe "type/0" do
    test "returns :map" do
      assert I18nEntry.type() == :map
    end
  end

  describe "cast/1" do
    test "accepts valid i18n entry with only en_US" do
      value = %{"en_US" => "Hello"}
      assert {:ok, ^value} = I18nEntry.cast(value)
    end

    test "accepts valid i18n entry with multiple locales" do
      value = %{
        "en_US" => "Hello",
        "zh_Hans" => "你好"
      }

      assert {:ok, ^value} = I18nEntry.cast(value)
    end

    test "accepts valid locale keys with script codes" do
      value = %{
        "en_US" => "Hello",
        "zh_Hans" => "你好",
        "zh_Hant" => "你好"
      }

      assert {:ok, ^value} = I18nEntry.cast(value)
    end

    test "rejects map without en_US key" do
      value = %{"zh_Hans" => "你好"}
      assert {:error, [message: "must contain \"en_US\" key"]} = I18nEntry.cast(value)
    end

    test "rejects map with non-string keys" do
      value = %{:en_US => "Hello"}
      assert {:error, [message: "all keys and values must be strings"]} = I18nEntry.cast(value)
    end

    test "rejects map with non-string values" do
      value = %{"en_US" => 123}
      assert {:error, [message: "all keys and values must be strings"]} = I18nEntry.cast(value)
    end

    test "rejects invalid locale key format - lang code too short" do
      value = %{"en_US" => "Hello", "z_Hans" => "你好"}
      assert {:error, [message: "invalid locale key: [\"z_Hans\"]"]} = I18nEntry.cast(value)
    end

    test "rejects invalid locale key format - lang code too long" do
      value = %{"en_US" => "Hello", "eng_US" => "Hello"}
      assert {:error, [message: "invalid locale key: [\"eng_US\"]"]} = I18nEntry.cast(value)
    end

    test "rejects invalid locale key format - lang code uppercase" do
      value = %{"en_US" => "Hello", "EN_US" => "Hello"}
      assert {:error, [message: "invalid locale key: [\"EN_US\"]"]} = I18nEntry.cast(value)
    end

    test "rejects invalid locale key format - country code lowercase" do
      value = %{"en_US" => "Hello", "zh_hans" => "你好"}
      assert {:error, [message: "invalid locale key: [\"zh_hans\"]"]} = I18nEntry.cast(value)
    end

    test "rejects invalid locale key format - no underscore" do
      value = %{"en_US" => "Hello", "enUS" => "Hello"}
      assert {:error, [message: "invalid locale key: [\"enUS\"]"]} = I18nEntry.cast(value)
    end

    test "rejects non-map value" do
      assert :error = I18nEntry.cast("en_US")
      assert :error = I18nEntry.cast(123)
      assert :error = I18nEntry.cast([:en_US])
    end
  end

  describe "load/1" do
    test "accepts valid map" do
      value = %{"en_US" => "Hello", "zh_Hans" => "你好"}
      assert {:ok, ^value} = I18nEntry.load(value)
    end

    test "accepts empty map" do
      value = %{}
      assert {:ok, ^value} = I18nEntry.load(value)
    end

    test "rejects non-map value" do
      assert :error = I18nEntry.load("en_US")
      assert :error = I18nEntry.load(123)
      assert :error = I18nEntry.load([:en_US])
    end
  end

  describe "dump/1" do
    test "accepts valid map" do
      value = %{"en_US" => "Hello", "zh_Hans" => "你好"}
      assert {:ok, ^value} = I18nEntry.dump(value)
    end

    test "accepts empty map" do
      value = %{}
      assert {:ok, ^value} = I18nEntry.dump(value)
    end

    test "rejects non-map value" do
      assert :error = I18nEntry.dump("en_US")
      assert :error = I18nEntry.dump(123)
      assert :error = I18nEntry.dump([:en_US])
    end
  end
end
