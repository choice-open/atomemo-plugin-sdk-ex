defmodule AtomemoPluginSdk.ParameterCodec do
  defprotocol Codecable do
    @spec cast(AtomemoPluginSdk.ParameterDefinition.t(), value :: any()) ::
            {:ok, casted_value :: any()} | {:error, [AtomemoPluginSdk.ParameterError.Entry.t()]}
    @spec cast(
            AtomemoPluginSdk.ParameterDefinition.t(),
            value :: any(),
            opts :: keyword()
          ) ::
            {:ok, casted_value :: any()} | {:error, [AtomemoPluginSdk.ParameterError.Entry.t()]}
    def cast(definition, value, opts \\ [])

    @spec cast_for_default(AtomemoPluginSdk.ParameterDefinition.t(), value :: any()) ::
            {:ok, casted_value :: any()} | {:error, [AtomemoPluginSdk.ParameterError.Entry.t()]}
    @spec cast_for_default(
            AtomemoPluginSdk.ParameterDefinition.t(),
            value :: any(),
            opts :: keyword()
          ) ::
            {:ok, casted_value :: any()} | {:error, [AtomemoPluginSdk.ParameterError.Entry.t()]}
    def cast_for_default(definition, value, opts \\ [])
  end

  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterError.Entry
  alias AtomemoPluginSdk.ParameterCodec.Base

  @callback validate(struct(), term(), keyword()) ::
              {:ok, any()} | {:error, [Entry.t()]}

  def validate_default(%{default: nil}), do: :ok

  def validate_default(%module{name: name, default: default} = definition) do
    if module.__allow_default__() do
      case Codecable.cast_for_default(definition, default) do
        {:ok, _} -> :ok
        {:error, entries} -> {:error, Error.new(entries)}
      end
    else
      {:error,
       "The default value is not allowed for #{definition.type} parameter definition."
       |> Entry.new(path: name)
       |> Error.new()}
    end
  end

  def cast(definition, value, opts \\ []) do
    with {:ok, value} <- Base.cast(definition, value),
         {:ok, value} <-
           if(is_nil(value), do: {:ok, nil}, else: Codecable.cast(definition, value, opts)) do
      {:ok, value}
    else
      {:error, entries} ->
        {:error, Error.new(entries, opts)}
    end
  end
end
