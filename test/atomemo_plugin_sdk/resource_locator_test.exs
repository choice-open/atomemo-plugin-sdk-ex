defmodule AtomemoPluginSdk.ResourceLocatorTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset
  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.ResourceLocator

  @valid_attrs %{
    "mode_name" => "list",
    "value" => "res_123",
    "cached_result_label" => "My Resource",
    "cached_result_url" => "https://example.com/res/123"
  }

  describe "hydrate_changeset/2" do
    test "casts all fields" do
      changeset = ResourceLocator.hydrate_changeset(%ResourceLocator{}, @valid_attrs)

      assert changeset.valid?
      assert get_field(changeset, :mode_name) == :list
      assert get_field(changeset, :value) == "res_123"
      assert get_field(changeset, :cached_result_label) == "My Resource"
      assert get_field(changeset, :cached_result_url) == "https://example.com/res/123"
    end

    test "accepts url and id mode_name" do
      assert ResourceLocator.hydrate_changeset(%ResourceLocator{}, %{"mode_name" => "url"}).valid?
      assert ResourceLocator.hydrate_changeset(%ResourceLocator{}, %{"mode_name" => "id"}).valid?
    end

    test "validates required mode_name" do
      changeset = ResourceLocator.hydrate_changeset(%ResourceLocator{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).mode_name
    end

    test "validates mode_name enum" do
      changeset =
        ResourceLocator.hydrate_changeset(%ResourceLocator{}, %{"mode_name" => "invalid"})

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).mode_name
    end

    test "allows nil optional fields" do
      changeset = ResourceLocator.hydrate_changeset(%ResourceLocator{}, %{"mode_name" => "list"})

      assert changeset.valid?
      assert get_field(changeset, :value) == nil
      assert get_field(changeset, :cached_result_label) == nil
      assert get_field(changeset, :cached_result_url) == nil
    end
  end

  describe "new/1" do
    test "returns ok with valid attrs" do
      assert {:ok, %ResourceLocator{} = loc} = ResourceLocator.new(@valid_attrs)
      assert loc.mode_name == :list
      assert loc.value == "res_123"
    end

    test "returns error with invalid attrs" do
      assert {:error, _msg} = ResourceLocator.new(%{})
    end

    test "returns error when input is not a map" do
      assert {:error, "not a map"} = ResourceLocator.new(:foo)
    end
  end

  describe "new!/1" do
    test "returns struct on success" do
      assert %ResourceLocator{} = ResourceLocator.new!(@valid_attrs)
    end

    test "raises on invalid input" do
      assert_raise AtomemoPluginSdk.ParameterError, fn ->
        ResourceLocator.new!(%{})
      end
    end
  end
end
