defmodule AnsiToHTMLTest do
  use ExUnit.Case
  doctest AnsiToHTML

  import AnsiToHTML

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "generate html string" do
    assert AnsiToHTML.generate_html("\e[34m[\e[0m\e[32m:hello\e[0m\e[34m]\e[0m") == "<pre><span style=\"color: blue;color: green;color: blue\">[:hello]</span></pre>"
  end

  test "generate html string with div container" do
    assert generate_html("\e[34m[\e[0m\e[32m:hello\e[0m\e[34m]\e[0m", :div) == "<div><span style=\"color: blue;color: green;color: blue\">[:hello]</span></div>"
  end

  test "generate phoenix html tag" do
    assert generate_phoenix_html("\e[34m[\e[0m\e[32m:hello\e[0m\e[34m]\e[0m") ==
      {:safe,
        [60, "pre", [], 62,
          [[60, "span",
            [[32, "style", 61, 34, "color: blue;color: green;color: blue", 34]], 62,
            ["[", ":hello", "]"], 60, 47, "span", 62]], 60, 47, "pre", 62]}
  end

  test "generate phoenix html with div tag container" do
    assert generate_phoenix_html("\e[34m[\e[0m\e[32m:hello\e[0m\e[34m]\e[0m", :div) ==
      {:safe,
        [60, "div", [], 62,
          [[60, "span",
            [[32, "style", 61, 34, "color: blue;color: green;color: blue", 34]], 62,
            ["[", ":hello", "]"], 60, 47, "span", 62]], 60, 47, "div", 62]}
  end
end
