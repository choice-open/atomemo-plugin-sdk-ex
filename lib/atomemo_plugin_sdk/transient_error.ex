defmodule AtomemoPluginSdk.TransientError do
  defexception [:code, :meta]

  @type code :: atom()
  @type t :: %__MODULE__{code: code(), meta: map()}

  defguardp is_network_error(code) when code in [:upload_failed, :download_failed]

  @spec new(code(), keyword()) :: t()
  def new(code, opts) when is_network_error(code) and is_list(opts) do
    %__MODULE__{code: code, meta: Map.new(opts)}
  end

  @impl true
  def message(%__MODULE__{
        code: code,
        meta: %{response: %Req.Response{status: status, body: body}}
      })
      when is_network_error(code) do
    "#{code}: server responded with status #{status}, body: #{inspect(body)}"
  end

  def message(%__MODULE__{code: code, meta: %{reason: error}}) when is_network_error(code) do
    "#{code}: #{inspect(error)}"
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{code: code} = exception) do
    %{"code" => "transient:#{code}", "message" => message(exception)}
  end
end
