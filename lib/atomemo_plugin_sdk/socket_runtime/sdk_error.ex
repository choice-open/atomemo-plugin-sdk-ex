defmodule AtomemoPluginSdk.SocketRuntime.SdkError do
  @moduledoc false

  defstruct [:code, :message]

  @type code :: atom()
  @type t :: %__MODULE__{code: code(), message: String.t()}

  @spec new(code(), String.t()) :: t()
  def new(code, message) when is_atom(code) and is_binary(message) do
    %__MODULE__{code: code, message: message}
  end

  @spec to_map(t() | map()) :: map()
  def to_map(%__MODULE__{code: code, message: message}) do
    %{"code" => "sdk:#{code}", "message" => message}
  end
end
