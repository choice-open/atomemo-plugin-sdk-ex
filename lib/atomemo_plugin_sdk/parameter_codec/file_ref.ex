defimpl AtomemoPluginSdk.ParameterCodec.Codecable,
  for: AtomemoPluginSdk.ParameterDefinition.FileRef do
  alias AtomemoPluginSdk.FileRef
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast_for_internal_default(%@for{}, %FileRef{source: :mem} = file_ref) do
    case FileRef.changeset(file_ref, %{}) do
      %{valid?: true} -> {:ok, file_ref}
      %{valid?: false} = changeset -> {:error, Entry.new(changeset)}
    end
  end

  def cast_for_internal_default(%@for{}, %FileRef{source: source}) do
    {:error,
     Entry.new("Invalid source for file_ref: only expected a mem FileRef struct, got: #{source}")}
  end

  def cast_for_internal_default(%@for{}, _value) do
    {:error, Entry.new("must be a %FileRef{} struct.")}
  end

  def cast(%@for{}, %{"__type__" => "file_ref"} = file_ref) do
    case FileRef.new(file_ref) do
      {:ok, file_ref} -> {:ok, file_ref}
      {:error, changeset} -> {:error, Entry.new(changeset)}
    end
  end

  def cast(%@for{}, _value) do
    {:error, Entry.new("must be a encoded file ref json payload.")}
  end
end
