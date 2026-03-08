defmodule AtomemoPluginSdk.SocketRuntime.ToolInvoker do
  @moduledoc """
  Handles tool invocation with timeout support.
  """

  require Logger

  alias AtomemoPluginSdk.ToolDefinition
  alias AtomemoPluginSdk.SdkError

  @max_timeout_ms 30 * 60 * 1_000

  @doc """
  Invokes a tool with timeout protection based on tool definition.

  Returns `{:ok, result}` on success or `{:error, reason}` on failure/timeout.
  """
  def invoke(tool, args) do
    timeout_ms = min(tool.timeout || @max_timeout_ms, @max_timeout_ms)
    task = Task.async(fn -> do_invoke(tool, args) end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task, 5_000) do
      {:ok, result} ->
        result

      nil ->
        Logger.warning(
          "[#{inspect(__MODULE__)}] Tool '#{tool.name}' invocation timed out after #{timeout_ms}ms"
        )

        {:error, SdkError.new(:timeout, "Tool '#{tool.name}' invocation timed out")}

      {:exit, reason} ->
        Logger.error(
          "[#{inspect(__MODULE__)}] Tool '#{tool.name}' invocation exited: #{inspect(reason)}"
        )

        {:error, SdkError.new(:crash, "Tool '#{tool.name}' invocation failed")}
    end
  end

  defp do_invoke(%ToolDefinition{} = tool, args) do
    case call_tool_invoke(tool, args) do
      {:ok, _result} = ok_tuple ->
        ok_tuple

      {:error, error} when is_map(error) ->
        Logger.error(
          "[#{inspect(__MODULE__)}] Failed to invoke tool '#{tool.name}': #{inspect(error)}"
        )

        {:error, error}
    end
  end

  defp call_tool_invoke(%ToolDefinition{} = tool, args) do
    try do
      result =
        if is_function(tool.invoke, 1) do
          tool.invoke.(args)
        else
          {:error, :invalid_tool_invoke}
        end

      case result do
        {:ok, _} = ok_tuple ->
          ok_tuple

        {:error, :invalid_tool_invoke} ->
          {:error,
           SdkError.new(
             :invalid_tool_invoke,
             "Tool '#{tool.name}' must have invoke function with 1 argument"
           )}

        {:error, error} when is_non_struct_map(error) ->
          {:error, error}

        {:error, message} when is_binary(message) ->
          {:error, %{"message" => message}}

        other ->
          {:error,
           SdkError.new(
             :invalid_return,
             "Unexpected return value from '#{tool.name}': #{inspect(other)}"
           )}
      end
    rescue
      err ->
        {:error,
         SdkError.new(
           :exception,
           "Exception during tool '#{tool.name}' invocation: #{Exception.message(err)}"
         )}
    catch
      kind, reason ->
        {:error,
         SdkError.new(
           :exception,
           "Caught #{kind} in tool '#{tool.name}': #{inspect(reason)}"
         )}
    end
  end
end
