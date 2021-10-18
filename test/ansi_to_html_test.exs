defmodule AnsiToHTMLTest do
  use ExUnit.Case
  doctest AnsiToHTML

  import AnsiToHTML
  import ExUnit.CaptureLog

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
        [32, "style", 61, 34,
          "font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;",
          34], 62,
        [[60, "span", [32, "style", 61, 34, "color: green;", 34], 62, [":hello"],
          60, 47, "span", 62]], 60, 47, "pre", 62]}
  end

  test "generate phoenix html with theme" do
    assert AnsiToHTML.generate_phoenix_html(@pretty_inspect, @custom_theme) ==
      {:safe,
      [60, "code",
        [32, "class", 61, 34,
          "container",
          34], 62,
        [[60, "pre", [32, "class", 61, 34, "green", 34], 62, [":hello"],
          60, 47, "pre", 62]], 60, 47, "code", 62]}
  end

  test "supports e[38;5;nm 8 bit coloring" do
    color_line = IO.ANSI.color(228) <> "Howdy Partner"
    assert AnsiToHTML.generate_html(color_line) ==
      "<pre style=\"font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;\"><span style=\"color: rgb(255, 255, 102);\">Howdy Partner</span></pre>"
  end

  test "supports e[38;2;r;g;bm 24 bit coloring" do
    color_line = IO.ANSI.color(5, 5, 2) <> "Howdy Partner"
    assert AnsiToHTML.generate_html(color_line) ==
      "<pre style=\"font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;\"><span style=\"color: rgb(255, 255, 102);\">Howdy Partner</span></pre>"
  end

  test "supports e[48;5;nm 8 bit background coloring" do
    color_line = IO.ANSI.color_background(228) <> "Howdy Partner"
    assert AnsiToHTML.generate_html(color_line) ==
      "<pre style=\"font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;\"><span style=\"background-color: rgb(255, 255, 102);\">Howdy Partner</span></pre>"
  end

  test "supports e[48;2;r;g;bm 24 bit background coloring" do
    color_line = IO.ANSI.color_background(5, 5, 2) <> "Howdy Partner"
    assert AnsiToHTML.generate_html(color_line) ==
      "<pre style=\"font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;\"><span style=\"background-color: rgb(255, 255, 102);\">Howdy Partner</span></pre>"
    end

  test "defaults to no styling if ANSI code not recognized" do
    color_line = "\e[1234m Howdy Partner"
    log_output = capture_log(fn ->
      assert AnsiToHTML.generate_html(color_line) ==
        "<pre style=\"font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;\"><text> Howdy Partner</text></pre>"
    end)
    log_output =~ "[AnsiToHTML] ignoring unsupported ANSI style - \"\\e[1234m\"\n\e[0m"
  end
end
