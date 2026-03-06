defmodule AtomemoPluginSdk.Context.LLM do
  alias AtomemoPluginSdk.Context
  alias AtomemoPluginSdk.SocketRuntime.HubCaller

  def invoke(
        %Context{__hub_client__: hub_client, organization_id: organization_id},
        llm_config,
        messages
      ) do
    HubCaller.call(
      hub_client,
      "invoke_llm",
      %{
        llm_config: llm_config,
        messages: messages,
        organization_id: organization_id
      },
      timeout: :timer.minutes(15)
    )
  end
end
