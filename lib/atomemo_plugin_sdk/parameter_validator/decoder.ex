defmodule AtomemoPluginSdk.ParameterValidator.Decoder do
  @supported_decoder_atoms [:json]
  @supported_decoder_strings Enum.map(@supported_decoder_atoms, &Atom.to_string/1)
  @supported_decoders @supported_decoder_atoms ++ @supported_decoder_strings

  defguardp is_supported_decoder(decoder) when decoder in @supported_decoders

  def decode_if_needed(_, nil), do: {:ok, nil}
  def decode_if_needed(nil, value), do: {:ok, value}

  def decode_if_needed(decoder, value)
      when is_binary(decoder) and is_supported_decoder(decoder) do
    decoder |> String.to_existing_atom() |> decode_if_needed(value)
  end

  def decode_if_needed(decoder, value) when is_supported_decoder(decoder) do
    do_decode(decoder, value)
  end

  def decode_if_needed(_, _),
    do: {:error, %{path: :decoder, message: "is not supported decoder."}}

  defp do_decode(:json, ""), do: {:ok, nil}

  defp do_decode(:json, value) do
    case JSON.decode(value) do
      {:ok, decoded_value} -> {:ok, decoded_value}
      _ -> {:error, %{path: :decoder, message: "can't decode to json for #{inspect(value)}"}}
    end
  end
end
