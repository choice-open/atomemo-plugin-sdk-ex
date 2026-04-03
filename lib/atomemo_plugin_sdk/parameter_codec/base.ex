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

  # NOTE
  # display 表示这个键是否存在，不止在 UI 层面，更是参数构造的逻辑之一。
  # 但现在我们是递归验证参数的，所以无法通过解析 display 的具体规则，只能简单的通过 display 是否含有逻辑来判断。
  # 正确的做法是通过 display 中的 hide 规则，来移除对应的键。
  # TODO 当 hide 规则命中后，实际不该校验 required 了，因为这个键已经被隐藏了。
  # 同时，default 也是不应该被使用的，因为这个键已经被隐藏了。
  defp validate_required(%{display: nil, required: true}, nil) do
    {:error, Entry.new("is required.")}
  end

  defp validate_required(%{display: display, required: true}, nil)
       when is_map(display) and map_size(display) == 0 do
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

  defp validate_enum(%{enum: enums}, value) when is_list(enums) do
    if value in enums do
      :ok
    else
      {:error, Entry.new("must be one of the enum values")}
    end
  end
end
