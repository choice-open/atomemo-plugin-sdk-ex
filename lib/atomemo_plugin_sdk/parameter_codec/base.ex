defmodule AtomemoPluginSdk.ParameterCodec.Base do
  alias AtomemoPluginSdk.ParameterCodec.Decoder
  alias AtomemoPluginSdk.ParameterError.Entry

  def cast(%{decoder: decoder} = definition, value) do
    with {:ok, value} <- Decoder.decode_if_needed(decoder, value),
         {:ok, value} <- take_default_if_needed(definition, value),
         :ok <- validate_required(definition, value),
         :ok <- validate_constant(definition, value),
         :ok <- validate_enum(definition, value) do
      {:ok, value}
    end
  end

  defp take_default_if_needed(%module{default: default} = definition, nil) do
    cond do
      is_nil(default) ->
        {:ok, nil}

      module.__allow_default__() ->
        {:ok, default}

      true ->
        {:error,
         Entry.new("The default value is not allowed in #{definition.type} parameter definition.")}
    end
  end

  defp take_default_if_needed(_definition, value), do: {:ok, value}

  defp validate_required(%{required: true}, nil) do
    {:error, Entry.new("is required.")}
  end

  defp validate_required(_, _), do: :ok

  defp validate_constant(_, nil), do: :ok
  defp validate_constant(%{constant: nil}, _), do: :ok
  defp validate_constant(%{constant: value}, value), do: :ok

  defp validate_constant(_, _) do
    {:error, Entry.new("must be the constant value.")}
  end

  defp validate_enum(%{enum: nil}, _), do: :ok
  defp validate_enum(_, nil), do: :ok

  defp validate_enum(%{enums: enums}, value) when is_list(enums) do
    if value in enums do
      :ok
    else
      {:error, Entry.new("must be one of the enum values")}
    end
  end
end
