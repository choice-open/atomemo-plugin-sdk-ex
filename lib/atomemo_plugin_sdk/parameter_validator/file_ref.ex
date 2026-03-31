defmodule AtomemoPluginSdk.ParameterValidator.FileRef do
  @moduledoc false

  use AtomemoPluginSdk.ParameterValidator

  alias AtomemoPluginSdk.ParameterValidator.Error
  alias AtomemoPluginSdk.FileRef

  @impl true
  def validate(_, %FileRef{source: :mem} = file_ref, _opts) do
    case FileRef.changeset(file_ref, %{}) do
      %{valid?: true} -> {:ok, file_ref}
      %{valid?: false} = changeset -> {:error, Error.issues_from_changeset(changeset)}
    end
  end

  def validate(_, %FileRef{source: source}, _opts) do
    {:error,
     %{
       path: :source,
       message:
         "Invalid default value for file_ref parameter definition: only expected mem FileRef struct, got: #{source}"
     }}
  end

  def validate(_, file_ref, opts) when is_map(file_ref) do
    if Keyword.get(opts, :source) != :default_definition do
      case FileRef.new(file_ref) do
        {:ok, file_ref} -> {:ok, file_ref}
        {:error, changeset} -> {:error, Error.issues_from_changeset(changeset)}
      end
    else
      {:error,
       %{
         path: :type,
         message:
           "Invalid default value for file_ref parameter definition: expected mem FileRef struct."
       }}
    end
  end

  def validate(_, _, _),
    do: {:error, %{path: :type, message: "must be a encoded file ref json payload."}}
end
