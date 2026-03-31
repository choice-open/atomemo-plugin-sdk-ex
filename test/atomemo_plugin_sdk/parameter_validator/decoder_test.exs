defmodule AtomemoPluginSdk.ParameterValidator.DecoderTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterValidator.Decoder

  describe "decode_if_needed/2" do
    test "returns ok nil when value is nil" do
      assert {:ok, nil} = Decoder.decode_if_needed(:json, nil)
    end

    test "returns original value when decoder is nil" do
      assert {:ok, "raw"} = Decoder.decode_if_needed(nil, "raw")
    end

    test "decodes json when decoder is atom" do
      assert {:ok, %{"hello" => "world"}} =
               Decoder.decode_if_needed(:json, "{\"hello\":\"world\"}")
    end

    test "decodes json when decoder is string" do
      assert {:ok, %{"count" => 2}} = Decoder.decode_if_needed("json", "{\"count\":2}")
    end

    test "returns ok nil for empty json payload" do
      assert {:ok, nil} = Decoder.decode_if_needed(:json, "")
    end

    test "returns error for invalid json" do
      assert {:error, %{path: :decoder, message: message}} = Decoder.decode_if_needed(:json, "{")
      assert message =~ "can't decode to json"
    end

    test "returns error for unsupported decoder" do
      assert {:error, %{path: :decoder, message: "is not supported decoder."}} =
               Decoder.decode_if_needed(:xml, "<a/>")
    end
  end
end
