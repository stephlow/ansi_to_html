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

      iex> AnsiToHTML.generate_html(inspect :hello, pretty: true, syntax_colors: [atom: :green])
      "<pre style=\\"font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;\\"><span style=\\"color: green;\\">:hello</span></pre>"

  """
  @spec generate_html(String.t, AnsiToHTML.Theme.t) :: String.t
  def generate_html(input, theme \\ %AnsiToHTML.Theme{}) when is_map(theme), do: input |> generate_phoenix_html(theme) |> safe_to_string()

  @doc """
  Generates a new Phoenix HTML tag based on the passed ANSI string.

  Returns `Phoenix.HTML.Tag.t`.

  ## Examples

      iex> AnsiToHTML.generate_phoenix_html(inspect :hello, pretty: true, syntax_colors: [atom: :green])
      {:safe,
      [60, "pre",
        [[32, "style", 61, 34,
          "font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;",
          34]], 62,
        [[60, "span", [[32, "style", 61, 34, "color: green;", 34]], 62, [":hello"],
          60, 47, "span", 62]], 60, 47, "pre", 62]}

  """
  @spec generate_phoenix_html(String.t, AnsiToHTML.Theme.t) :: Phoenix.HTML.Tag.t
  def generate_phoenix_html(input, theme \\ %AnsiToHTML.Theme{}) when is_map(theme) do
    tokens = input
    |> String.replace(~r/\e\[(K|s|u|2J|2K|\d+(A|B|C|D|E|F|G|J|K|S|T)|\d+;\d+(H|f))/, "") # Remove cursor movement sequences
    |> String.replace(~r/#^.*\r(?!\n)#m/, "") # Remove carriage return
    |> tokenize
    |> convert_to_tag(theme)

    {container_tag, container_attr} = Map.get(theme, :container)

    content_tag container_tag, tokens, container_attr
  end

  defp convert_to_tag(tokens, theme) do
    tokens |> Enum.map(fn(token) ->
      token |> Map.get(:styles, []) |> Enum.reduce(nil, fn(style, acc) ->
        {token_tag, token_attr} = Map.get(theme, :"#{style}")

        content_tag(token_tag, acc || Map.get(token, :text), token_attr)
      end);
    end)
  end

  defp tokenize(text) do
    text
    |> String.split(~r/(?:\e\[(.*?)m|(\x08))/, include_captures: true, trim: true) # Split by ANSI code
    |> Enum.chunk_by(&(String.equivalent?(&1, "\e[0m"))) # Split the result into chunks by ANSI reset
    |> Enum.reject(fn(token) -> Enum.count(token) == 1 && String.starts_with?(List.first(token), "\e[") end) # Remove chunks which have only one style
    |> Enum.map(fn(token) -> Enum.group_by(token, &get_token_type/1) end) # Group token data by type
  end

  defp get_token_type(token) do
    case String.starts_with?(token, "\e[") do
      true -> :styles
      false -> :text
    end
  end
end
