defmodule AtomemoPluginSdk.ParameterValidator.ErrorTest do
  use ExUnit.Case, async: true

  alias AtomemoPluginSdk.ParameterValidator.Error

  test "stores multiple issues" do
    issues = [
      %{path: ["default"], message: "must be a string."},
      %{path: ["default", "name"], message: "too short"}
    ]

    error = Error.new(issues, source: :default_definition)

    assert error.source == :default_definition
    assert error.issues == issues
  end

  test "formats message with issue count" do
    issues = [
      %{path: [:default], message: "must be a string."},
      %{path: [:default, "items", 0, "name"], message: "too short"}
    ]

    error = Error.new(issues, source: :default_definition)

    assert Exception.message(error) ==
             "default: must be a string.\ndefault.items[0].name: too short"
  end

  test "formats empty path" do
    error = Error.new([%{path: [], message: "must be an object."}], source: :runtime_input)

    assert Exception.message(error) == ": must be an object."
  end

  test "accepts a single issue input" do
    issue = %{path: ["default"], message: "must be a string."}

    error = Error.new(issue, source: :runtime_input)

    assert error.source == :runtime_input
    assert error.issues == [issue]
  end

  test "uses explicit exception message when provided" do
    error = Error.new("parameter validation failed", source: :runtime_input)

    assert error.source == :runtime_input
    assert error.issues == []
    assert Exception.message(error) == "parameter validation failed"
  end

  describe "format_path/1" do
    test "formats atom-only path" do
      error =
        Error.new([%{path: [:config, :timeout], message: "invalid"}], source: :runtime_input)

      assert Exception.message(error) == "config.timeout: invalid"
    end

    test "formats mixed atom and string path" do
      error =
        Error.new([%{path: [:default, "name"], message: "is required"}],
          source: :default_definition
        )

      assert Exception.message(error) == "default.name: is required"
    end

    test "formats path with consecutive array indices" do
      error =
        Error.new([%{path: [:matrix, 0, 1], message: "out of range"}], source: :runtime_input)

      assert Exception.message(error) == "matrix[0][1]: out of range"
    end

    test "formats path starting with array index" do
      error = Error.new([%{path: [0, "name"], message: "is required"}], source: :runtime_input)

      assert Exception.message(error) == "[0].name: is required"
    end

    test "formats single-segment string path" do
      error =
        Error.new([%{path: ["username"], message: "too long"}], source: :default_definition)

      assert Exception.message(error) == "username: too long"
    end

    test "formats single-segment atom path" do
      error = Error.new([%{path: [:age], message: "must be positive"}], source: :runtime_input)

      assert Exception.message(error) == "age: must be positive"
    end
  end
end
