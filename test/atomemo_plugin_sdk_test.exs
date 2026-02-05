defmodule AtomemoPluginSdkTest do
  use ExUnit.Case
  doctest AtomemoPluginSdk

  test "greets the world" do
    assert AtomemoPluginSdk.hello() == :world
  end
end
