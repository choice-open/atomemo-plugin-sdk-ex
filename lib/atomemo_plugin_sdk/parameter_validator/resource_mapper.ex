defmodule AtomemoPluginSdk.ParameterValidator.ResourceMapper do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator

  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ResourceMapper

  @impl true
  def validate(_, %ResourceMapper{} = value, _opts) do
    case value |> Map.from_struct() |> ResourceMapper.new() do
      {:ok, resource_mapper} -> {:ok, resource_mapper}
      {:error, changeset} -> {:error, Error.issues_from_changeset(changeset)}
    end
  end

  def validate(_, %{"__type__" => "resource_mapper"} = value, _opts) do
    case ResourceMapper.new(value) do
      {:ok, resource_mapper} -> {:ok, resource_mapper}
      {:error, changeset} -> {:error, Error.issues_from_changeset(changeset)}
    end
  end

  def validate(_, _, _) do
    {:error, %{path: :type, message: "must be an encoded resource mapper payload."}}
  end
end
