defmodule AtomemoPluginSdk.ParameterValidator do
  alias AtomemoPluginSdk.ParameterError, as: Error
  alias AtomemoPluginSdk.ParameterValidator.Decoder
  alias AtomemoPluginSdk.ParameterValidator.Base

  @type issue :: Error.issue()
  @type source :: :input | :plugin

  @callback validate(struct(), term(), keyword()) ::
              {:ok, any()} | {:error, [issue()] | issue()}

  defmacro __using__(_opts) do
    quote do
      @behaviour AtomemoPluginSdk.ParameterValidator
      @impl true
      def validate(_struct, value, _opts) do
        {:ok, value}
      end

      defoverridable validate: 3

      defdelegate cast(struct, value, opts), to: AtomemoPluginSdk.ParameterValidator
    end
  end

  def validate_default(%{default: nil}), do: :ok

  def validate_default(%module{default: default} = definition) do
    opts = [source: :plugin]

    if module.__allow_default__() do
      case cast(definition, default, opts) do
        {:ok, _} -> :ok
        {:error, %Error{}} = error -> error
      end
    else
      {:error,
       Error.new(
         "The default value is not allowed in #{definition.type} parameter definition.",
         opts
       )}
    end
  end

  def cast(%module{decoder: decoder} = definition, value, opts \\ []) do
    {original_source, others} = Keyword.pop(opts, :source)
    opts = [{:source, original_source || :input} | others]

    with {:ok, value} <- decode_if_needed(decoder, value, opts),
         value <- use_default_if_needed(definition, value),
         {:ok, value} <- Base.validate(definition, value, opts),
         {:ok, value} <-
           if(is_nil(value),
             do: {:ok, nil},
             else: module.__validator_module__().validate(definition, value, opts)
           ) do
      {:ok, value}
    else
      {:error, message} when is_binary(message) ->
        {:error, Error.new(message, opts)}

      {:error, issues} ->
        {:error, Error.new(issues, opts)}
    end
  end

  defp decode_if_needed(decoder, value, opts) do
    case opts[:source] do
      :input -> Decoder.decode_if_needed(decoder, value)
      :plugin -> {:ok, value}
    end
  end

  defp use_default_if_needed(%module{default: default}, nil) do
    if module.__allow_default__() do
      default
    else
      nil
    end
  end

  defp use_default_if_needed(_definition, value), do: value
end
