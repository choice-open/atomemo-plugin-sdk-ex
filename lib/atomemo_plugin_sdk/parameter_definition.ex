defmodule AtomemoPluginSdk.ParameterDefinition do
  @moduledoc """
  参数结构体，用于描述插件的参数。
  """

  import Ecto.Changeset
  import PolymorphicEmbed

  @type t() ::
          AtomemoPluginSdk.ParameterDefinition.String.t()
          | AtomemoPluginSdk.ParameterDefinition.Number.t()
          | AtomemoPluginSdk.ParameterDefinition.Boolean.t()
          | AtomemoPluginSdk.ParameterDefinition.Object.t()
          | AtomemoPluginSdk.ParameterDefinition.Array.t()
          | AtomemoPluginSdk.ParameterDefinition.DiscriminatedUnion.t()
          | AtomemoPluginSdk.ParameterDefinition.CredentialId.t()
          | AtomemoPluginSdk.ParameterDefinition.EncryptedString.t()
          | AtomemoPluginSdk.ParameterDefinition.FileRef.t()

  defmacro __using__(_opts) do
    quote do
      alias unquote(__MODULE__)
      import unquote(__MODULE__)
    end
  end

  defmacro parameters(field_name) do
    quote do
      polymorphic_embeds_many unquote(field_name),
        type_field_name: :type,
        on_replace: :delete,
        types: [
          string: AtomemoPluginSdk.ParameterDefinition.String,
          number: AtomemoPluginSdk.ParameterDefinition.Number,
          integer: AtomemoPluginSdk.ParameterDefinition.Number,
          boolean: AtomemoPluginSdk.ParameterDefinition.Boolean,
          object: AtomemoPluginSdk.ParameterDefinition.Object,
          array: AtomemoPluginSdk.ParameterDefinition.Array,
          discriminated_union: AtomemoPluginSdk.ParameterDefinition.DiscriminatedUnion,
          credential_id: AtomemoPluginSdk.ParameterDefinition.CredentialId,
          encrypted_string: AtomemoPluginSdk.ParameterDefinition.EncryptedString,
          file_ref: AtomemoPluginSdk.ParameterDefinition.FileRef
        ]
    end
  end

  defmacro parameter(field_name) do
    quote do
      polymorphic_embeds_one unquote(field_name),
        type_field_name: :type,
        on_replace: :update,
        types: [
          string: AtomemoPluginSdk.ParameterDefinition.String,
          number: AtomemoPluginSdk.ParameterDefinition.Number,
          integer: AtomemoPluginSdk.ParameterDefinition.Number,
          boolean: AtomemoPluginSdk.ParameterDefinition.Boolean,
          object: AtomemoPluginSdk.ParameterDefinition.Object,
          array: AtomemoPluginSdk.ParameterDefinition.Array,
          discriminated_union: AtomemoPluginSdk.ParameterDefinition.DiscriminatedUnion,
          credential_id: AtomemoPluginSdk.ParameterDefinition.CredentialId,
          encrypted_string: AtomemoPluginSdk.ParameterDefinition.EncryptedString,
          file_ref: AtomemoPluginSdk.ParameterDefinition.FileRef
        ]
    end
  end

  def cast_parameters(changeset, field_name) do
    changeset
    |> cast_polymorphic_embed(field_name)
    |> validate_unique_parameter_names(field_name)
  end

  defp validate_unique_parameter_names(changeset, field_name) do
    params = get_field(changeset, field_name) || []

    names =
      Enum.reduce(params, [], fn param, acc ->
        case Map.get(param, :name) do
          nil -> acc
          name -> [name | acc]
        end
      end)

    duplicates =
      names
      |> Enum.frequencies()
      |> Enum.filter(fn {_name, count} -> count > 1 end)
      |> Enum.map(fn {name, _count} -> name end)

    if duplicates != [] do
      add_error(
        changeset,
        field_name,
        "parameter names must be unique, found duplicates: #{inspect(duplicates)}"
      )
    else
      changeset
    end
  end

  def cast_parameter(changeset, field_name) do
    changeset
    |> cast_polymorphic_embed(field_name)
  end
end
