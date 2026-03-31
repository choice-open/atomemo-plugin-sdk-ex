defmodule AtomemoPluginSdk.ParameterValidator.BaseTest.AllowDefaultParameter do
  def validate(_definition, value, _opts) do
    if is_binary(value) do
      {:ok, value}
    else
      {:error, [%{path: :default, message: "must be a string."}]}
    end
  end
end

defmodule AtomemoPluginSdk.ParameterValidator.BaseTest.DisallowDefaultParameter do
  def validate(_definition, value, _opts), do: {:ok, value}
end

defmodule AtomemoPluginSdk.ParameterDefinition.BaseTest do
  use ExUnit.Case, async: true

  import AtomemoPluginSdk.TestHelpers

  defmodule AllowDefaultParameter do
    use Ecto.Schema
    use AtomemoPluginSdk.ParameterDefinition.Base, allow_default: true

    @primary_key false
    embedded_schema do
      base_schema()
      field :type, :string
      field :min_length, :integer
      field :max_length, :integer
    end

    def changeset(schema, attrs) do
      schema
      |> cast_and_validate_base_fields(attrs)
      |> validate_default_if_needed()
    end
  end

  defmodule DisallowDefaultParameter do
    use Ecto.Schema
    use AtomemoPluginSdk.ParameterDefinition.Base, allow_default: false

    @primary_key false
    embedded_schema do
      base_schema()
      field :type, :string
    end

    def changeset(schema, attrs) do
      schema
      |> cast_and_validate_base_fields(attrs)
      |> validate_default_if_needed()
    end
  end

  describe "__using__/1" do
    test "raises on non-boolean allow_default option" do
      module_name = "InvalidAllowDefault#{System.unique_integer([:positive])}"

      code = """
      defmodule #{module_name} do
        use Ecto.Schema
        use AtomemoPluginSdk.ParameterDefinition.Base, allow_default: \"false\"

        @primary_key false
        embedded_schema do
          base_schema()
          field :type, :string, default: \"string\"
        end

      end
      """

      assert_raise ArgumentError, ~r/invalid :allow_default option/, fn ->
        Code.compile_string(code)
      end
    end

    test "raises when corresponding validator module is missing" do
      module_name = "MissingValidator#{System.unique_integer([:positive])}"

      code = """
      defmodule AtomemoPluginSdk.ParameterDefinition.#{module_name} do
        use Ecto.Schema
        use AtomemoPluginSdk.ParameterDefinition.Base

        @primary_key false
        embedded_schema do
          base_schema()
          field :type, :string, default: \"string\"
        end
      end
      """

      assert_raise CompileError, ~r/missing corresponding validator module/, fn ->
        Code.compile_string(code)
      end
    end

    test "raises when corresponding validator has no validate/3" do
      module_name = "MissingValidateMethod#{System.unique_integer([:positive])}"

      code = """
      defmodule AtomemoPluginSdk.ParameterValidator.#{module_name} do
      end

      defmodule AtomemoPluginSdk.ParameterDefinition.#{module_name} do
        use Ecto.Schema
        use AtomemoPluginSdk.ParameterDefinition.Base

        @primary_key false
        embedded_schema do
          base_schema()
          field :type, :string, default: \"string\"
        end
      end
      """

      assert_raise CompileError, ~r/must define validate\/3/, fn ->
        Code.compile_string(code)
      end
    end
  end

  describe "validate_default_if_needed/1" do
    test "skips validation when changeset is invalid" do
      changeset = AllowDefaultParameter.changeset(%AllowDefaultParameter{}, %{default: "bad"})

      refute changeset.valid?
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "skips validation when default is nil" do
      changeset =
        DisallowDefaultParameter.changeset(%DisallowDefaultParameter{}, %{type: "credential_id"})

      assert changeset.valid?
      assert errors_on(changeset) == %{}
    end

    test "adds validator error when default validation fails" do
      changeset =
        AllowDefaultParameter.changeset(%AllowDefaultParameter{}, %{
          type: "string",
          default: 123
        })

      refute changeset.valid?
      assert %{default: ["default: must be a string."]} = errors_on(changeset)
    end
  end
end
