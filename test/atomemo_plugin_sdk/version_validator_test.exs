defmodule AtomemoPluginSdk.VersionValidatorTest do
  use ExUnit.Case

  import Ecto.Changeset
  import AtomemoPluginSdk.TestHelpers

  alias AtomemoPluginSdk.VersionValidator

  defmodule TestSchema do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :version, :string
    end
  end

  describe "validate_version/2" do
    test "accepts valid SemVer versions" do
      valid_versions = [
        "1.0.0",
        "0.1.0",
        "10.20.30",
        "1.0.0-alpha",
        "1.0.0-alpha.1",
        "1.0.0-alpha.beta",
        "1.0.0-alpha.1.beta.2",
        "1.0.0+build.1",
        "1.0.0+build.1.2",
        "1.0.0-alpha+build.1",
        "1.0.0-alpha.1+build.1.2",
        "1.0.0-rc.1+build.123"
      ]

      for version <- valid_versions do
        changeset =
          %TestSchema{}
          |> change(%{version: version})
          |> VersionValidator.validate_version()

        assert changeset.valid?, "Expected '#{version}' to be valid"
      end
    end

    test "rejects versions without PATCH" do
      invalid_versions = [
        "1.0",
        "1",
        "10"
      ]

      for version <- invalid_versions do
        changeset =
          %TestSchema{}
          |> change(%{version: version})
          |> VersionValidator.validate_version()

        refute changeset.valid?, "Expected '#{version}' to be invalid (missing PATCH)"
        assert %{version: [_error]} = errors_on(changeset)
      end
    end

    test "rejects versions with underscores" do
      invalid_versions = [
        "1.0.0_alpha",
        "1__0__0",
        "1.0.0-alpha_1",
        "1.0.0+build_1",
        "1_0_0"
      ]

      for version <- invalid_versions do
        changeset =
          %TestSchema{}
          |> change(%{version: version})
          |> VersionValidator.validate_version()

        refute changeset.valid?, "Expected '#{version}' to be invalid (contains underscore)"
        assert %{version: [_error]} = errors_on(changeset)
      end
    end

    test "rejects invalid pre-release formats" do
      invalid_versions = [
        "1.0.0-",
        "1.0.0-.",
        "1.0.0-alpha.",
        "1.0.0-.alpha"
      ]

      for version <- invalid_versions do
        changeset =
          %TestSchema{}
          |> change(%{version: version})
          |> VersionValidator.validate_version()

        refute changeset.valid?, "Expected '#{version}' to be invalid (invalid pre-release)"
      end
    end

    test "rejects invalid build metadata formats" do
      invalid_versions = [
        "1.0.0+",
        "1.0.0+.",
        "1.0.0+build.",
        "1.0.0+.build"
      ]

      for version <- invalid_versions do
        changeset =
          %TestSchema{}
          |> change(%{version: version})
          |> VersionValidator.validate_version()

        refute changeset.valid?, "Expected '#{version}' to be invalid (invalid build metadata)"
      end
    end
  end
end
