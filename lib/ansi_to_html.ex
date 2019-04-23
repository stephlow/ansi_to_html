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
    # swap backgroud and forground code
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
    |> Enum.map(fn(token) ->
      token
      |> Map.get(:styles, [])
      |> case do
        [] ->
          content_tag(:text, token.text)
        styles ->
          Enum.reduce(styles, nil, fn(style, acc) ->
            {token_tag, token_attr} = Map.get(theme, :"#{style}")
    
            content_tag(token_tag, acc || Map.get(token, :text), token_attr)
          end)
      end
    end)
  end

  defp tokenize(text) do
    text
    |> String.split(~r/(?:\e\[(.*?)m|(\x08))/, include_captures: true, trim: true) # Split by ANSI code
    |> chunk_by_ansi_codes([])
    |> Enum.map(fn(token) -> Enum.group_by(token, &get_token_type/1) end) # Group token data by type
  end

  defp get_token_type(token) do
    case String.starts_with?(token, "\e[") do
      true -> :styles
      false -> :text
    end
  end
end
