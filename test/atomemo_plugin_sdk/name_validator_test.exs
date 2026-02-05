defmodule AtomemoPluginSdk.NameValidatorTest do
  use ExUnit.Case

  import Ecto.Changeset
  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.NameValidator

  defmodule TestSchema do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :name, :string
    end
  end

  describe "validate_name/2" do
    test "accepts valid names" do
      valid_names = [
        "valid",
        "validName",
        "valid_name",
        "valid-name",
        "valid123",
        "a1234",
        "a" <> String.duplicate("b", 63) <> "c",
        "MyPlugin",
        "my_plugin",
        "my-plugin"
      ]

      for name <- valid_names do
        changeset =
          %TestSchema{}
          |> change(%{name: name})
          |> NameValidator.validate_name()

        assert changeset.valid?, "Expected '#{name}' to be valid"
      end
    end

    test "rejects names that don't start with a letter" do
      invalid_names = [
        "123invalid",
        "_invalid",
        "-invalid",
        "0invalid"
      ]

      for name <- invalid_names do
        changeset =
          %TestSchema{}
          |> change(%{name: name})
          |> NameValidator.validate_name()

        refute changeset.valid?, "Expected '#{name}' to be invalid"
        assert %{name: [error]} = errors_on(changeset)
        assert error =~ "must start with a letter"
      end
    end

    test "rejects names that don't end with a letter or number" do
      invalid_names = [
        "invalid_",
        "invalid-",
        "validName_",
        "validName-"
      ]

      for name <- invalid_names do
        changeset =
          %TestSchema{}
          |> change(%{name: name})
          |> NameValidator.validate_name()

        refute changeset.valid?, "Expected '#{name}' to be invalid"
      end
    end

    test "rejects names with consecutive underscores" do
      invalid_names = [
        "invalid__name",
        "test__",
        "__test",
        "a__b"
      ]

      for name <- invalid_names do
        changeset =
          %TestSchema{}
          |> change(%{name: name})
          |> NameValidator.validate_name()

        refute changeset.valid?, "Expected '#{name}' to be invalid"
        assert %{name: [_error]} = errors_on(changeset)
      end
    end

    test "rejects names with consecutive hyphens" do
      invalid_names = [
        "invalid--name",
        "test--",
        "--test",
        "a--b"
      ]

      for name <- invalid_names do
        changeset =
          %TestSchema{}
          |> change(%{name: name})
          |> NameValidator.validate_name()

        refute changeset.valid?, "Expected '#{name}' to be invalid"
        assert %{name: [_error]} = errors_on(changeset)
      end
    end

    test "rejects names that are too short" do
      invalid_names = [
        "a",
        "ab",
        "abc",
        "abcd"
      ]

      for name <- invalid_names do
        changeset =
          %TestSchema{}
          |> change(%{name: name})
          |> NameValidator.validate_name()

        refute changeset.valid?, "Expected '#{name}' to be invalid (too short)"
      end
    end

    test "rejects names that are too long" do
      # Name pattern requires: 1 letter + 3-63 chars + 1 letter/number = 5-65 chars
      # Test with 66+ chars
      invalid_name = "a" <> String.duplicate("b", 64) <> "c"

      changeset =
        %TestSchema{}
        |> change(%{name: invalid_name})
        |> NameValidator.validate_name()

      refute changeset.valid?
      assert %{name: [_error]} = errors_on(changeset)
    end
  end
end
