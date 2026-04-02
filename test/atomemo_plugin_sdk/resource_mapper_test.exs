defmodule AtomemoPluginSdk.ResourceMapperTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset
  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.ResourceMapper

  @valid_attrs %{
    "mapping_mode" => "manual",
    "value" => %{"field_a" => "col_1", "field_b" => "col_2"}
  }

  describe "hydrate_changeset/2" do
    test "casts all fields" do
      changeset = ResourceMapper.hydrate_changeset(%ResourceMapper{}, @valid_attrs)

      assert changeset.valid?
      assert get_field(changeset, :mapping_mode) == :manual
      assert get_field(changeset, :value) == %{"field_a" => "col_1", "field_b" => "col_2"}
    end

    test "accepts auto mapping_mode" do
      changeset =
        ResourceMapper.hydrate_changeset(%ResourceMapper{}, %{"mapping_mode" => "auto"})

      assert changeset.valid?
      assert get_field(changeset, :mapping_mode) == :auto
      assert get_field(changeset, :value) == nil
    end

    test "validates required mapping_mode" do
      changeset = ResourceMapper.hydrate_changeset(%ResourceMapper{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).mapping_mode
    end

    test "validates mapping_mode enum" do
      changeset =
        ResourceMapper.hydrate_changeset(%ResourceMapper{}, %{"mapping_mode" => "invalid"})

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).mapping_mode
    end

    test "allows nil optional value" do
      changeset = ResourceMapper.hydrate_changeset(%ResourceMapper{}, %{"mapping_mode" => "auto"})

      assert changeset.valid?
      assert get_field(changeset, :value) == nil
    end
  end

  describe "new/1" do
    test "returns ok with valid attrs" do
      assert {:ok, %ResourceMapper{} = mapper} = ResourceMapper.new(@valid_attrs)
      assert mapper.mapping_mode == :manual
      assert mapper.value == %{"field_a" => "col_1", "field_b" => "col_2"}
    end

    test "returns error with invalid attrs" do
      assert {:error, _msg} = ResourceMapper.new(%{})
    end

    test "returns error when input is not a map" do
      assert {:error, "not a map"} = ResourceMapper.new(:foo)
    end
  end

  describe "new!/1" do
    test "returns struct on success" do
      assert %ResourceMapper{} = ResourceMapper.new!(@valid_attrs)
    end

    test "raises on invalid input" do
      assert_raise AtomemoPluginSdk.ParameterError, fn ->
        ResourceMapper.new!(%{})
      end
    end
  end
end
