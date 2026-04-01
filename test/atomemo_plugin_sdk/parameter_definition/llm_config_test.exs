defmodule AtomemoPluginSdk.ParameterDefinition.LLMConfigTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterDefinition.LLMConfig, as: PDLLMConfig

  test "allows default values" do
    assert PDLLMConfig.__allow_default__() == false
  end
end
