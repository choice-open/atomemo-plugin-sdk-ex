defmodule AtomemoPluginSdk.ParameterHydratorTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.{FileRef, LLMConfig, ParameterHydrator}

  test "hydrates nested runtime structs in maps and lists" do
    raw = %{
      "attachment" => %{
        "__type__" => "file_ref",
        "source" => "mem",
        "filename" => "note.txt",
        "content" => Base.encode64("hello")
      },
      "configs" => [
        %{
          "__type__" => "llm_config",
          "version_slug" => "demo_plugin__release__1.0.0",
          "model" => "gpt-4.1",
          "model_params" => %{"structured_outputs" => true}
        }
      ],
      :plain => %{"foo" => "bar"}
    }

    hydrated = ParameterHydrator.hydrate(raw)

    assert %FileRef{source: :mem, filename: "note.txt", content: "hello"} =
             hydrated["attachment"]

    assert [
             %LLMConfig{
               version_slug: "demo_plugin__release__1.0.0",
               model: "gpt-4.1",
               model_params: %LLMConfig.ModelParams{structured_outputs: true}
             }
           ] = hydrated["configs"]

    assert hydrated[:plain] == %{"foo" => "bar"}
  end

  test "supports atom-keyed runtime maps" do
    raw = %{
      file: %{
        __type__: "file_ref",
        source: "oss",
        res_key: "reports/2026-03.csv"
      }
    }

    hydrated = ParameterHydrator.hydrate(raw)

    assert %FileRef{source: :oss, res_key: "reports/2026-03.csv"} = hydrated.file
  end

  test "keeps ordinary maps unchanged" do
    raw = %{"source" => "oss", "kind" => "plain_map"}

    assert ParameterHydrator.hydrate(raw) == raw
  end

  test "keeps maps with unknown runtime types unchanged except for recursive children" do
    raw = %{
      "__type__" => "unknown",
      "nested" => %{
        "__type__" => "file_ref",
        "source" => "oss",
        "res_key" => "reports/2026-03.csv"
      }
    }

    hydrated = ParameterHydrator.hydrate(raw)

    assert hydrated["__type__"] == "unknown"
    assert %FileRef{source: :oss, res_key: "reports/2026-03.csv"} = hydrated["nested"]
  end

  test "keeps existing structs unchanged" do
    file_ref = %FileRef{source: :oss, res_key: "reports/2026-03.csv"}

    assert ParameterHydrator.hydrate(file_ref) == file_ref
  end

  test "hydrates lists and leaves scalar values untouched" do
    raw = [
      %{
        "__type__" => "file_ref",
        "source" => "mem",
        "filename" => "note.txt",
        "content" => Base.encode64("hello")
      },
      42,
      "plain"
    ]

    assert [%FileRef{source: :mem, filename: "note.txt", content: "hello"}, 42, "plain"] =
             ParameterHydrator.hydrate(raw)
  end
end
