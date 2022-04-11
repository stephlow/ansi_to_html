# AnsiToHTML

Small library to convert ANSI Styling codes to HTML using [phoenix_html](https://github.com/phoenixframework/phoenix_html).
The library is not solely intended for use with `Phoenix` and can be easily used without it.

## Installation

The package can be installed by adding `ansi_to_html` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:ansi_to_html, "~> 0.5.1"}]
end
```

### Why and how should I use this?

I wrote this package so I could have all the nice things that Elixir's `Kernel.inspect/2` does for my productivity, all from the comfort of my `Phoenix.View`.

#### Generating a HTML String:
This is useful if you're not using `Phoenix`:
```elixir
iex> AnsiToHTML.generate_html("\e[34m[\e[0m\e[32m:hello\e[0m\e[34m]\e[0m")
"<pre><span style=\"color: blue;color: green;color: blue;\">[:hello]</span></pre>"
```

#### Generating Phoenix HTML Tags:
This is useful if you actually are using `Phoenix` and want to render in your views:
```elixir
iex> AnsiToHTML.generate_phoenix_html("\e[34m[\e[0m\e[32m:hello\e[0m\e[34m]\e[0m")
{:safe,
  [60, "pre", [], 62,
    [[60, "span",
      [[32, "style", 61, 34, "color: blue;color: green;color: blue;", 34]], 62,
      ["[", ":hello", "]"], 60, 47, "span", 62]], 60, 47, "pre", 62]}
```

## Custom Themes

You can use the `AnsiToHTML.Theme` struct to map ANSI codes to html.
The struct defaults to a `<pre>` tag containing common tags such as `<strong>`, `<i>`, `<u>`, or otherwise `<span>` tags with inline styles.

## Phoenix View Helper

You can define a helper function in your view which uses `AnsiToHTML` to convert a pretty `Kernel.inspect/2` to html:

```elixir
defmodule MyApp.Web do
  # ...

  def view do
    quote do
      # ...

      # See the docs on Inspect.Opts for more information
      # https://hexdocs.pm/elixir/Inspect.Opts.html
      @syntax_colors [string: :green, map: :blue]
      def pretty_inspect(variable), do: AnsiToHTML.generate_phoenix_html inspect variable, pretty: true, syntax_colors: @syntax_colors

    end
  end

# ...

end
```

Now you can use the helper function in your templates:

```elixir
<%= pretty_inspect @conn %>
<%= pretty_inspect @assigns %>
```
