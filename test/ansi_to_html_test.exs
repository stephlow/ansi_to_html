defmodule AnsiToHTMLTest do
  use ExUnit.Case
  doctest AnsiToHTML

  import AnsiToHTML

  @pretty_inspect inspect :hello, pretty: true, syntax_colors: [atom: :green]

  @custom_theme %AnsiToHTML.Theme{
    container: {:code, [class: "container"]},
    "\e[32m": {:pre, [class: "green"]}
  }

  test "generate html string" do
    assert AnsiToHTML.generate_html(@pretty_inspect) ==
            "<pre style=\"font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;\"><span style=\"color: green;\">:hello</span></pre>"
  end

  test "generate html string with theme" do
    assert AnsiToHTML.generate_html(@pretty_inspect, @custom_theme) ==
            "<code class=\"container\"><pre class=\"green\">:hello</pre></code>"
  end

  test "generate phoenix html tag" do
    assert generate_phoenix_html(@pretty_inspect) ==
      {:safe,
      [60, "pre",
        [[32, "style", 61, 34,
          "font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;",
          34]], 62,
        [[60, "span", [[32, "style", 61, 34, "color: green;", 34]], 62, [":hello"],
          60, 47, "span", 62]], 60, 47, "pre", 62]}
  end

  test "generate phoenix html with theme" do
    assert AnsiToHTML.generate_phoenix_html(@pretty_inspect, @custom_theme) ==
      {:safe,
      [60, "code",
        [[32, "class", 61, 34,
          "container",
          34]], 62,
        [[60, "pre", [[32, "class", 61, 34, "green", 34]], 62, [":hello"],
          60, 47, "pre", 62]], 60, 47, "code", 62]}
  end
end
