defmodule AnsiToHTML do
  use Phoenix.HTML
  @moduledoc """
  AnsiToHTML is a small library to convert ANSI Styling codes to HTML using [phoenix_html](https://github.com/phoenixframework/phoenix_html).
  The library is not solely intented for use with `Phoenix` and can be easily used without it.
  """

  @doc """
  Generates a new HTML string based on the passed ANSI string.

  Returns `String.t`.

  ## Examples

      iex> AnsiToHTML.generate_html("\e[34m[\e[0m\e[32m:hello\e[0m\e[34m]\e[0m")
      "<pre><span style=\\"color: blue;color: green;color: blue\\">[:hello]</span></pre>"

      iex> AnsiToHTML.generate_html("\e[34m[\e[0m\e[32m:hello\e[0m\e[34m]\e[0m", :div)
      "<div><span style=\\"color: blue;color: green;color: blue\\">[:hello]</span></div>"

  """
  @spec generate_html(String.t, atom) :: String.t
  def generate_html(input, container_tag \\ :pre), do: input |> generate_phoenix_html(container_tag) |> safe_to_string()

  @doc """
  Generates a new Phoenix HTML tag based on the passed ANSI string.

  Returns `Phoenix.HTML.Tag.t`.

  ## Examples

      iex> AnsiToHTML.generate_phoenix_html("\e[34m[\e[0m\e[32m:hello\e[0m\e[34m]\e[0m")
      {:safe,
        [60, "pre", [], 62,
          [[60, "span",
            [[32, "style", 61, 34, "color: blue;color: green;color: blue", 34]], 62,
            ["[", ":hello", "]"], 60, 47, "span", 62]], 60, 47, "pre", 62]}

      iex> AnsiToHTML.generate_phoenix_html("\e[34m[\e[0m\e[32m:hello\e[0m\e[34m]\e[0m", :div)
      {:safe,
        [60, "div", [], 62,
          [[60, "span",
            [[32, "style", 61, 34, "color: blue;color: green;color: blue", 34]], 62,
            ["[", ":hello", "]"], 60, 47, "span", 62]], 60, 47, "div", 62]}

  """
  @spec generate_phoenix_html(String.t, atom) :: Phoenix.HTML.Tag.t
  def generate_phoenix_html(input, container_tag \\ :pre) do
    tokens = input
    |> String.replace(~r/\e\[(K|s|u|2J|2K|\d+(A|B|C|D|E|F|G|J|K|S|T)|\d+;\d+(H|f))/, "") # Remove cursor movement sequences
    |> String.replace(~r/#^.*\r(?!\n)#m/, "") # Remove carriage return
    |> tokenize
    |> convert_to_tag

    content_tag container_tag, tokens
  end

  defp convert_to_tag(tokens), do: tokens |> Enum.map(&content_tag(:span, Map.get(&1, :text), style: ansi_to_css(Map.get(&1, :styles))))

  defp tokenize(text) do
    text
    |> String.split(~r/(?:\e\[(.*?)m|(\x08))/, include_captures: true, trim: true) # Split by ANSI code
    |> Enum.chunk_by(&(String.equivalent?(&1, "\e[37m") or String.equivalent?(&1, "\e[39m"))) # Split the result into chunks by ANSI white or reset (Kernel.inspect/2 uses white as a reset)
    |> Enum.reject(fn(token) -> Enum.count(token) == 1 && String.starts_with?(List.first(token), "\e[") end) # Remove chunks which have only one style
    |> Enum.map(fn(token) -> Enum.group_by(token, &get_token_type/1) end) # Group token data by type
  end

  defp get_token_type(token) do
    case String.starts_with?(token, "\e[") do
      true -> :styles
      false -> :text
    end
  end

  defp ansi_to_css(styles) do
    styles
    |> Enum.map(fn(style) ->
        case style do
          "\e[1m" -> "font-weight: bold"
          "\e[3m" -> "font-style: italic"
          "\e[4m" -> "text-decoration: underline"
          "\e[9m" -> "text-decoration: line-through"
          "\e[30m" -> "color: black"
          "\e[31m" -> "color: red"
          "\e[32m" -> "color: green"
          "\e[33m" -> "color: yellow"
          "\e[34m" -> "color: blue"
          "\e[35m" -> "color: magenta"
          "\e[36m" -> "color: cyan"
          "\e[37m" -> "color: white"
          _ -> ""
        end
      end)
    |> Enum.reject(&String.equivalent?(&1, ""))
    |> Enum.join(";")
  end

end
