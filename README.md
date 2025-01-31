[![Hex Version](https://img.shields.io/hexpm/v/broadcast)](https://hex.pm/packages/broadcast) [![Hex Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/broadcast/)


# Broadcast 

Broadcast is an Elixir library for posting to social media websites, currently with support for Bluesky and Mastodon.

## Installation

Add `broadcast` to your list of dependancies in `mix.exs`:

```elixir
def deps do
  [
    {:broadcast, "~> 0.1.0"}
  ]
end
```

Then run `mix deps.get` to install dependencies. Broadcast requires Elixir 1.17 or later.

## Usage

Post to Bluesky and Mastodon simultaneously, with `post_all/1`:

```elixir
{:ok, results} = Broadcast.post_all(
  %{
    status: "Hello, world!",
    mastodon_access_token: "your_mastodon_access_token",
    bluesky_handle: "your_bluesky_handle",
    bluesky_password: "your_bluesky_password"
  }
)
```

Post to Mastodon, with `post_mastodon_status/2`:

```elixir
{:ok, results} = Broadcast.post_mastodon_status(
  "mastodon_access_token",
  "Hello world!"
)
```

Post to Bluesky, with `post_bluesky_status/3`:

```elixir
{:ok, result} = Broadcast.post_bluesky_status(
  "your_bluesky_handle",
  "your_bluesky_password",
  "Hello world!"
)
```

## License

Broadcast's source code is released under the [MIT License](https://github.com/skyefreeman/broadcast.ex/blob/main/LICENSE).

