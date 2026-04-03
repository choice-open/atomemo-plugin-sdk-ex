defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.FileRef do
  alias AtomemoPluginSdk.FileRef
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_default(
        %@for{},
        %{"__type__" => "file_ref", "source" => "mem"} = file_ref,
        _opts
      ) do
    case FileRef.changeset(file_ref) do
      %{valid?: true} -> {:ok, file_ref}
      %{valid?: false} = changeset -> {:error, Entry.new(changeset)}
    end
  end

  def cast_for_default(%@for{}, %{"__type__" => "file_ref", "source" => source}, _opts) do
    {:error,
     Entry.new("Invalid source for file_ref: only expected a mem FileRef struct, got: #{source}")}
  end

  def cast_for_default(%@for{}, _value, _opts) do
    {:error, Entry.new("must be a encoded file ref json payload.")}
  end

  def cast(%@for{}, file_ref, _opts) when is_map(file_ref) do
    case FileRef.new(file_ref) do
      {:ok, file_ref} -> {:ok, file_ref}
      {:error, changeset} -> {:error, Entry.new(changeset)}
    end
  end

  def cast(%@for{}, _value, _opts) do
    {:error, Entry.new("must be a encoded file ref json payload.")}
  end
end
