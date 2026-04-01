defmodule AtomemoPluginSdk.ParameterDefinition.Base do
  @moduledoc """
  ParameterDefinition 的公共基础字段，对应 TS 中的 `NodePropertyBase`。
  """

  import Ecto.Changeset

  alias AtomemoPluginSdk.{I18nEntry, JSONValue}

  defmacro base_schema do
    quote do
      field :decoder, Ecto.Enum, values: [:json]
      field :name, :string
      field :display_name, I18nEntry
      field :required, :boolean, default: false
      field :display, :map
      field :constant, JSONValue
      field :default, JSONValue
      field :enum, {:array, JSONValue}
      field :depends_on, {:array, :string}
      field :ai, :map
      field :ui, :map
    end
  end

  defmacro __using__(opts) do
    allow_default = Keyword.get(opts, :allow_default, true)

    case is_boolean(allow_default) do
      true ->
        :ok

      false ->
        raise ArgumentError,
              "invalid :allow_default option for use #{inspect(__MODULE__)}: " <>
                "expected boolean, got #{inspect(allow_default)}"
    end

    quote do
      @after_compile {unquote(__MODULE__), :ensure_validator_module!}

      import unquote(__MODULE__)
      alias AtomemoPluginSdk.ParameterValidator, as: PV

      def __allow_default__, do: unquote(allow_default)

      def validate_default_if_needed(changeset) do
        cond do
          not changeset.valid? ->
            changeset

          changeset |> get_field(:default) |> is_nil() ->
            changeset

          true ->
            case changeset |> apply_changes() |> PV.validate_default() do
              :ok ->
                changeset

              {:error, %AtomemoPluginSdk.ParameterError{} = error} ->
                add_error(changeset, :default, AtomemoPluginSdk.ParameterError.message(error))
            end
        end
      end
    end
  end

  def ensure_validator_module!(env, _bytecode) do
    definition_module = env.module
    validator_module = validator_module_for_definition(definition_module)

    case Code.ensure_compiled(validator_module) do
      {:module, _module} ->
        if function_exported?(validator_module, :validate, 3) do
          :ok
        else
          raise CompileError,
            file: env.file,
            line: env.line,
            description:
              "#{inspect(validator_module)} must define validate/3 for #{inspect(definition_module)}"
        end

      {:error, _reason} ->
        raise CompileError,
          file: env.file,
          line: env.line,
          description:
            "missing corresponding validator module #{inspect(validator_module)} for #{inspect(definition_module)}"
    end
  end

  defp validator_module_for_definition(definition_module) do
    definition_module
    |> Module.split()
    |> Enum.map(fn
      "ParameterDefinition" -> "ParameterValidator"
      segment -> segment
    end)
    |> Module.concat()
  end

  def cast_and_validate_base_fields(changeset, attrs) do
    changeset
    |> cast(attrs, [
      :decoder,
      :type,
      :name,
      :display_name,
      :required,
      :display,
      :constant,
      :default,
      :enum,
      :depends_on,
      :ai,
      :ui
    ])
    |> validate_required([:type])
  end
end
