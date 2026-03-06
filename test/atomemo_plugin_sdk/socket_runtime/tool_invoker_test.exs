defmodule AtomemoPluginSdk.SocketRuntime.ToolInvokerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias AtomemoPluginSdk.SocketRuntime.{SdkError, ToolInvoker}
  alias AtomemoPluginSdk.ToolDefinition

  test "returns invalid_tool_invoke for legacy invoke/2 callback" do
    tool = %ToolDefinition{
      name: "legacy_tool",
      invoke: fn _params, _credentials -> {:ok, %{}} end
    }

    args = %{parameters: %{}, credentials: %{}, context: nil}

    assert {{:error, %SdkError{code: :invalid_tool_invoke, message: message}}, log} =
             with_log(fn -> ToolInvoker.invoke(tool, args) end)

    assert message == "Tool 'legacy_tool' must have invoke function with 1 argument"
    assert log =~ "Failed to invoke tool 'legacy_tool'"
  end
end
