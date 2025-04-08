[![Hex Version](https://img.shields.io/hexpm/v/broadcast)](https://hex.pm/packages/broadcast) [![Hex Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/broadcast/)


# Broadcast 

Broadcast is an Elixir library for posting to social media websites, currently with support for Bluesky and Mastodon.

## Features

- Post to multiple social media platforms with a single function call
- Support for both Mastodon and Bluesky platforms
- Image attachment support (multiple images per post)
- Reply to existing posts
- Hashtag detection and formatting for Bluesky
- Link detection and formatting for Bluesky

## Installation

Add `broadcast` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:broadcast, "~> 0.2.0"}
  ]
end
```

Then run `mix deps.get` to install dependencies. Broadcast requires Elixir 1.17 or later.

## Usage

### Post to Multiple Platforms

Post to Bluesky and Mastodon simultaneously with `post_all/1`:

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

### Post with Media

Add media attachments to your posts with the `media_paths` parameter:

```elixir
{:ok, results} = Broadcast.post_all(
  %{
    status: "Check out this image!",
    mastodon_access_token: "your_mastodon_access_token",
    bluesky_handle: "your_bluesky_handle",
    bluesky_password: "your_bluesky_password",
    media_paths: ["path/to/image.jpg", "path/to/another.png"]
  }
)
```

### Post Replies

Reply to existing posts on both platforms simultaneously:

```elixir
{:ok, results} = Broadcast.post_all(
  %{
    status: "This is my reply!",
    mastodon_access_token: "your_mastodon_access_token",
    bluesky_handle: "your_bluesky_handle",
    bluesky_password: "your_bluesky_password",
    mastodon_reply_id: "109372843234", # ID of the Mastodon post to reply to
    bluesky_reply: %{
      # Both root and parent are required for Bluesky replies
      root: %{uri: "at://did:123/app.bsky.feed.post/original", cid: "bafyreihg6tz"},
      parent: %{uri: "at://did:123/app.bsky.feed.post/parent", cid: "bafyreiabc123"}
    }
  }
)
```

### Platform-Specific Functions

#### Mastodon

Post to Mastodon only:

```elixir
{:ok, result} = Broadcast.post_mastodon_status(
  "mastodon_access_token",
  "Hello world!"
)
```

Reply to a Mastodon post:

```elixir
{:ok, result} = Broadcast.post_mastodon_status(
  "mastodon_access_token",
  "This is a reply!",
  [], # Optional media paths
  "109372843234" # ID of the post to reply to
)
```

#### Bluesky

Post to Bluesky only:

```elixir
{:ok, result} = Broadcast.post_bluesky_status(
  "your_bluesky_handle",
  "your_bluesky_password",
  "Hello world!"
)
```

Reply to a Bluesky post:

```elixir
reply_info = %{
  root: %{uri: "at://did:123/app.bsky.feed.post/original", cid: "bafyreihg6tz"},
  parent: %{uri: "at://did:123/app.bsky.feed.post/parent", cid: "bafyreiabc123"}
}

{:ok, result} = Broadcast.post_bluesky_status(
  "your_bluesky_handle",
  "your_bluesky_password",
  "This is a reply!",
  [], # Optional media paths
  reply_info
)
```

## License

Broadcast's source code is released under the [MIT License](https://github.com/skyefreeman/broadcast.ex/blob/main/LICENSE).

