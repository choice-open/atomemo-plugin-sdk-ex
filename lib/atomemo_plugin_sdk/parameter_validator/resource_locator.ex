defmodule AtomemoPluginSdk.ParameterValidator.ResourceLocator do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator

  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ResourceLocator

  @impl true
  def validate(_, %ResourceLocator{} = value, _opts) do
    case value |> Map.from_struct() |> ResourceLocator.new() do
      {:ok, resource_locator} -> {:ok, resource_locator}
      {:error, changeset} -> {:error, Error.issues_from_changeset(changeset)}
    end
  end

  def validate(_, %{"__type__" => "resource_locator"} = value, _opts) do
    case ResourceLocator.new(value) do
      {:ok, resource_locator} -> {:ok, resource_locator}
      {:error, changeset} -> {:error, Error.issues_from_changeset(changeset)}
    end
  end

  def validate(_, _, _) do
    {:error, %{path: :type, message: "must be an encoded resource locator payload."}}
  end
end
