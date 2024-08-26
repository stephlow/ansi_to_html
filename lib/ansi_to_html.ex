defmodule AnsiToHTML do
  import Phoenix.HTML
  use PhoenixHTMLHelpers

  @moduledoc """
  AnsiToHTML is a small library to convert ANSI Styling codes to HTML using [phoenix_html](https://github.com/phoenixframework/phoenix_html).
  The library is not solely intended for use with `Phoenix` and can be easily used without it.
  """

  @doc """
  Generates a new HTML string based on the passed ANSI string.

  Returns `String.t`.

  ## Examples

      iex> AnsiToHTML.generate_html(inspect :hello, pretty: true, syntax_colors: [atom: :green])
      "<pre style=\\"font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;\\"><span style=\\"color: green;\\">:hello</span></pre>"

  """
  @spec generate_html(String.t(), AnsiToHTML.Theme.t()) :: String.t()
  def generate_html(input, theme \\ %AnsiToHTML.Theme{}) when is_map(theme),
    do: input |> generate_phoenix_html(theme) |> safe_to_string()

  @doc """
  Generates a new Phoenix HTML tag based on the passed ANSI string.

  Returns `Phoenix.HTML.Tag.t`.

  ## Examples

      iex> AnsiToHTML.generate_phoenix_html(inspect :hello, pretty: true, syntax_colors: [atom: :green])
      {:safe,
      [60, "pre",
        [32, "style", 61, 34,
          "font-family: monospace; font-size: 12px; padding: 4px; background-color: black; color: white;",
          34], 62,
        [[60, "span", [32, "style", 61, 34, "color: green;", 34], 62, [":hello"],
          60, 47, "span", 62]], 60, 47, "pre", 62]}

  """
  @spec generate_phoenix_html(String.t(), AnsiToHTML.Theme.t()) :: Phoenix.HTML.Tag.t()
  def generate_phoenix_html(input, theme \\ %AnsiToHTML.Theme{}) when is_map(theme) do
    tokens =
      input
      # Remove cursor movement sequences
      |> String.replace(~r/\e\[(K|s|u|2J|2K|\d+(A|B|C|D|E|F|G|J|K|S|T)|\d+;\d+(H|f))/, "")
      # Remove carriage return
      |> String.replace(~r/#^.*\r(?!\n)#m/, "")
      |> tokenize
      |> convert_to_tag(theme)

    case theme.container do
      :none ->
        tokens

      {container_tag, container_attr} ->
        content_tag(container_tag, tokens, container_attr)
    end
  end

  defp accumulate_ansi_chunks([], acc, chunks) do
    chunk_by_ansi_codes([], [acc | chunks])
  end

  defp accumulate_ansi_chunks(["\e[0m" | rem], acc, chunks) do
    chunk_by_ansi_codes(rem, [acc | chunks])
  end

  defp accumulate_ansi_chunks(["\e[" <> _ = code | rem], acc, chunks) do
    accumulate_ansi_chunks(rem, [code], [acc | chunks])
  end

  defp accumulate_ansi_chunks([next | rem], acc, chunks) do
    accumulate_ansi_chunks(rem, [next | acc], chunks)
  end

  defp chunk_by_ansi_codes([], chunks), do: Enum.reverse(chunks)

  defp chunk_by_ansi_codes(["\e[0m" | rem], chunks) do
    chunk_by_ansi_codes(rem, chunks)
  end

  defp chunk_by_ansi_codes(["\e[7m" | rem], chunks) do
    # swap background and foreground code
    # if the next piece is a text color code, then this
    # attempts to make that the background and default
    # the text to black
    case rem do
      [<<"\e[3", color::binary-size(1), "m">> | next_rem] ->
        accumulate_ansi_chunks(next_rem, ["\e[4#{color}m", "\e[30m"], chunks)

      _ ->
        chunk_by_ansi_codes(rem, chunks)
    end
  end

  defp chunk_by_ansi_codes(["\e[" <> _ = code | rem], chunks) do
    accumulate_ansi_chunks(rem, [code], chunks)
  end

  defp chunk_by_ansi_codes([next | rem], []) do
    chunk_by_ansi_codes(rem, [[next]])
  end

  defp chunk_by_ansi_codes([next | rem], chunks) do
    chunk_by_ansi_codes(rem, [[next] | chunks])
  end

  defp convert_to_tag(tokens, theme) do
    tokens
    |> Enum.map(fn token ->
      token
      |> Map.get(:styles, [])
      |> case do
        [] ->
          content_tag(:text, token.text)

        styles ->
          Enum.reduce(styles, nil, fn style, acc ->
            {token_tag, token_attr} = Map.get(theme, :"#{style}") || default_style(style)

            content_tag(token_tag, acc || Map.get(token, :text), token_attr)
          end)
      end
    end)
  end

  defp tokenize(text) do
    text
    # Split by ANSI code
    |> String.split(~r/(?:\e\[(.*?)m|(\x08))/, include_captures: true, trim: true)
    |> chunk_by_ansi_codes([])
    # Group token data by type
    |> Enum.map(fn token -> Enum.group_by(token, &get_token_type/1) end)
  end

  defp get_token_type(token) do
    case String.starts_with?(token, "\e[") do
      true -> :styles
      false -> :text
    end
  end

  defp default_style(style) do
    style =
      Regex.scan(~r/[[:digit:]]+/, style)
      |> List.flatten()
      |> Enum.map(&String.to_integer/1)
      |> style_by_token()

    case style do
      [] -> {:text, []}
      _ -> {:span, [style: style]}
    end
  end

  defp style_by_token([1 | tail]), do: ["font-weight: bold;" | style_by_token(tail)]
  defp style_by_token([2 | tail]), do: ["font-weight: lighter;" | style_by_token(tail)]
  defp style_by_token([3 | tail]), do: ["font-style: italic;" | style_by_token(tail)]
  defp style_by_token([4 | tail]), do: ["text-decoration: underline;" | style_by_token(tail)]
  defp style_by_token([5 | tail]), do: ["text-decoration: blink;" | style_by_token(tail)]
  defp style_by_token([7 | tail]), do: ["filter: invert(100%);" | style_by_token(tail)]
  defp style_by_token([8 | tail]), do: ["visibility: hidden;" | style_by_token(tail)]
  defp style_by_token([9 | tail]), do: ["text-decoration: line-through;" | style_by_token(tail)]

  defp style_by_token([21 | tail]),
    do: ["font-weight: normal; text-decoration: underline;" | style_by_token(tail)]

  defp style_by_token([22 | tail]), do: ["font-weight: normal;" | style_by_token(tail)]
  defp style_by_token([23 | tail]), do: ["font-style: normal;" | style_by_token(tail)]
  defp style_by_token([24 | tail]), do: ["text-decoration: none;" | style_by_token(tail)]
  defp style_by_token([25 | tail]), do: ["text-decoration: none;" | style_by_token(tail)]
  defp style_by_token([27 | tail]), do: ["filter: none;" | style_by_token(tail)]
  defp style_by_token([28 | tail]), do: ["visibility: visible;" | style_by_token(tail)]
  defp style_by_token([29 | tail]), do: ["text-decoration: none;" | style_by_token(tail)]
  defp style_by_token([53 | tail]), do: ["text-decoration: overline;" | style_by_token(tail)]
  defp style_by_token([55 | tail]), do: ["text-decoration: none;" | style_by_token(tail)]

  defp style_by_token([30 | tail]), do: ["color: black;" | style_by_token(tail)]
  defp style_by_token([31 | tail]), do: ["color: red;" | style_by_token(tail)]
  defp style_by_token([32 | tail]), do: ["color: green;" | style_by_token(tail)]
  defp style_by_token([33 | tail]), do: ["color: yellow;" | style_by_token(tail)]
  defp style_by_token([34 | tail]), do: ["color: blue;" | style_by_token(tail)]
  defp style_by_token([35 | tail]), do: ["color: magenta;" | style_by_token(tail)]
  defp style_by_token([36 | tail]), do: ["color: cyan;" | style_by_token(tail)]
  defp style_by_token([37 | tail]), do: ["color: white;" | style_by_token(tail)]
  # default to the text color in browser
  # defp style_by_token([ 39 | tail ]) ": {:text, []},
  defp style_by_token([40 | tail]), do: ["background-color: black;" | style_by_token(tail)]
  defp style_by_token([41 | tail]), do: ["background-color: red;" | style_by_token(tail)]
  defp style_by_token([42 | tail]), do: ["background-color: green;" | style_by_token(tail)]
  defp style_by_token([43 | tail]), do: ["background-color: yellow;" | style_by_token(tail)]
  defp style_by_token([44 | tail]), do: ["background-color: blue;" | style_by_token(tail)]
  defp style_by_token([45 | tail]), do: ["background-color: magenta;" | style_by_token(tail)]
  defp style_by_token([46 | tail]), do: ["background-color: cyan;" | style_by_token(tail)]
  defp style_by_token([47 | tail]), do: ["background-color: white;" | style_by_token(tail)]

  # \e[48;5;228m - 8 bit color (Xterm)
  # \e[48;2;255;255;102m - 24 bit RGB
  defp style_by_token([38 | tail]) do
    {{r, g, b}, tail} = custom_color(tail)
    ["color: rgb(#{r}, #{g}, #{b});" | style_by_token(tail)]
  end

  # \e[48;5;228m - 8 bit color (Xterm)
  # \e[48;2;255;255;102m - 24 bit RGB
  defp style_by_token([48 | tail]) do
    {{r, g, b}, tail} = custom_color(tail)
    ["background-color: rgb(#{r}, #{g}, #{b});" | style_by_token(tail)]
  end

  defp style_by_token([49 | tail]), do: ["background-color: black;" | style_by_token(tail)]

  defp style_by_token([]), do: []

  defp style_by_token([unknown_style_code | tail]) do
    require Logger

    Logger.warning(
      "[AnsiToHTML] ignoring unsupported ANSI style - #{inspect(unknown_style_code)}"
    )

    style_by_token(tail)
  end

  defp custom_color([2, r, g, b | tail]) do
    {{r, g, b}, tail}
  end

  defp custom_color([5, colour | tail]) do
    {parse_rgb(colour, "5"), tail}
  end

  defp parse_rgb(rgb_m, "2") when is_bitstring(rgb_m) do
    # 255;255;203m
    Regex.scan(~r/[[:digit:]]+/, rgb_m)
    |> List.flatten()
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple()
  end

  defp parse_rgb(color_m, "5") when is_bitstring(color_m) do
    # 228m
    Integer.parse(color_m)
    |> elem(0)
    |> parse_rgb("5")
  end

  defp parse_rgb(color, "5") when is_number(color) do
    color = color - 16
    blue = rem(color, 6) |> Kernel.*(51)
    green = div(color, 6) |> rem(6) |> Kernel.*(51)
    red = div(color, 36) |> rem(6) |> Kernel.*(51)
    {red, green, blue}
  end
end
