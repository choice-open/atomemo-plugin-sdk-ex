defmodule AtomemoPluginSdk.SocketRuntime.CallbackRunner do
  @moduledoc """
  Unified runtime for async callback dispatch with timeout and error normalization.
  """

  require Logger

  alias AtomemoPluginSdk.{Context, SdkError, TransientError}

  @default_shutdown_timeout_ms 5_000

  @type opts :: [
          {:label, String.t()}
          | {:timeout_ms, pos_integer()}
          | {:shutdown_timeout_ms, pos_integer()}
          | {:invalid_callback_error, SdkError.t()}
        ]

  @spec dispatch((map() -> any()), map(), keyword()) :: :ok
  def dispatch(callback, args, opts) when is_map(args) and is_list(opts) do
    task_supervisor = Keyword.fetch!(opts, :task_supervisor)
    %Context{} = context = Keyword.fetch!(opts, :context)
    ok_event = Keyword.fetch!(opts, :ok_event)
    error_event = Keyword.fetch!(opts, :error_event)
    topic = Keyword.fetch!(opts, :topic)
    run_opts = Keyword.fetch!(opts, :run_opts)
    request_id = context.request_id
    hub_client = context.__hub_client__

    Task.Supervisor.start_child(task_supervisor, fn ->
      case run(callback, args, run_opts) do
        {:ok, data} ->
          send(hub_client, {ok_event, topic, request_id, data})

        {:error, error} ->
          send(hub_client, {error_event, topic, request_id, error})
      end
    end)

    :ok
  end

  @spec run((map() -> any()), map(), opts()) ::
          {:ok, map()} | {:error, map() | SdkError.t() | TransientError.t()}
  def run(callback, args, opts) when is_map(args) do
    label = Keyword.fetch!(opts, :label)
    timeout_ms = Keyword.fetch!(opts, :timeout_ms)
    shutdown_timeout_ms = Keyword.get(opts, :shutdown_timeout_ms, @default_shutdown_timeout_ms)
    invalid_callback_error = Keyword.fetch!(opts, :invalid_callback_error)

    if is_function(callback, 1) do
      task = Task.async(fn -> invoke(callback, args, label) end)

      case Task.yield(task, timeout_ms) || Task.shutdown(task, shutdown_timeout_ms) do
        {:ok, result} ->
          result

        nil ->
          Logger.warning("[#{inspect(__MODULE__)}] #{label} timed out after #{timeout_ms}ms")

          {:error, SdkError.new(:timeout, "#{label} timed out")}

        {:exit, reason} ->
          Logger.error("[#{inspect(__MODULE__)}] #{label} exited: #{inspect(reason)}")

          {:error, SdkError.new(:crash, "#{label} failed")}
      end
    else
      {:error, invalid_callback_error}
    end
  end

  defp invoke(callback, args, label) do
    result =
      try do
        callback.(args)
      rescue
        err ->
          {:error,
           SdkError.new(:exception, "Exception during #{label}: #{Exception.message(err)}")}
      catch
        kind, reason ->
          {:error, SdkError.new(:exception, "Caught #{kind} in #{label}: #{inspect(reason)}")}
      end

    case result do
      {:ok, result} when is_map(result) ->
        {:ok, result}

      {:ok, message} when is_binary(message) ->
        {:ok, %{"message" => message}}

      {:ok, other} ->
        {:error,
         SdkError.new(:invalid_return, "Unexpected return value from #{label}: #{inspect(other)}")}

      {:error, %TransientError{} = error} ->
        {:error, error}

      {:error, %SdkError{} = error} ->
        {:error, error}

      {:error, error} when is_non_struct_map(error) ->
        {:error, error}

      {:error, message} when is_binary(message) ->
        {:error, %{"message" => message}}

      other ->
        {:error,
         SdkError.new(:invalid_return, "Unexpected return value from #{label}: #{inspect(other)}")}
    end
  end
end
