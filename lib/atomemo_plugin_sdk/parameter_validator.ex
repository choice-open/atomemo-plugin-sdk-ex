defmodule AtomemoPluginSdk.ParameterValidator do
  alias AtomemoPluginSdk.ParameterValidator.Error
  alias AtomemoPluginSdk.ParameterValidator.Decoder
  alias AtomemoPluginSdk.ParameterValidator.Base

  @type issue :: Error.issue()
  @type source :: :input | :plugin

  @callback validate(struct(), term(), keyword()) ::
              {:ok, any()} | {:error, [issue() | String.t()] | Error.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour AtomemoPluginSdk.ParameterValidator
      @impl true
      def validate(_struct, value, _opts) do
        {:ok, value}
      end

      defoverridable validate: 3
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
    opts = [source: Keyword.get(opts, :source, :input)]

    with {:ok, value} <- decode_if_needed(decoder, value, opts),
         value <- use_default_if_needed(definition, value),
         {:ok, value} <- Base.validate(definition, value, opts),
         {:ok, value} <-
           if(value,
             do: validator_mod(module).validate(definition, value, opts),
             else: {:ok, nil}
           ) do
      {:ok, value}
    else
      {:error, %Error{} = error} ->
        {:error, error}

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

  defp validator_mod(module) do
    module
    |> Module.split()
    |> Enum.map(fn
      "ParameterDefinition" -> "ParameterValidator"
      segment -> segment
    end)
    |> Module.concat()
  end
end
