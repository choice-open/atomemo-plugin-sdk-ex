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
      import unquote(__MODULE__)

      def __allow_default__, do: unquote(allow_default)
    end
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
