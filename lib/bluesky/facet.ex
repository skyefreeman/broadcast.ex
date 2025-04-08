defmodule Bluesky.Facet do
  @moduledoc """
  Helper module for interfacing with the Bluesky Facet API:  https://docs.bsky.app/docs/advanced-guides/post-richtext
  """

  @doc """
  Extracts both link and hashtag facets from the given text.

  Scans the input text for URLs and hashtags, returning their positions along
  with associated features.

  ## Parameters

    - `text`: A string containing the text to scan for links and hashtags.

  ## Examples

      iex> Bluesky.Facet.facets("Visit us at https://example.com, and use #elixir")
      [
        %{
          "index" => %{"byteStart" => 12, "byteEnd" => 31},
          "features" => [%{"$type" => "app.bsky.richtext.facet#link", "uri" => "https://example.com"}]
        },
        %{
          "index" => %{"byteStart" => 41, "byteEnd" => 48},
          "features" => [%{"$type" => "app.bsky.richtext.facet#tag", "tag" => "elixir"}]
        }
      ]
  """
  def facets(text) do
    link_facets = links(text)
    hashtag_facets = hashtags(text)

    link_facets ++ hashtag_facets
  end

  @doc """
  Extracts link facets from the given text.

  Scans the input text for URLs and returns their positions along with
  associated features.

  ## Parameters

    - `text`: A string containing the text to scan for links.

  ## Examples

      iex> Bluesky.Facet.links("Visit us at https://example.com.")
      [
        %{
          "index" => %{"byteStart" => 12, "byteEnd" => 31},
          "features" => [%{"$type" => "app.bsky.richtext.facet#link", "uri" => "https://example.com"}]
        }
      ]
      
      iex> Bluesky.Facet.links("Check out https://sub.example.com/path, it's cool!")
      [
        %{
          "index" => %{"byteStart" => 10, "byteEnd" => 38},
          "features" => [%{"$type" => "app.bsky.richtext.facet#link", "uri" => "https://sub.example.com/path"}]
        }
      ]
  """
  def links(text) do
    # First pass: match URLs with the protocol
    url_regex = ~r/https?:\/\/[a-zA-Z0-9][-a-zA-Z0-9.]*\.[a-zA-Z0-9][-a-zA-Z0-9%_.~\/#?&=:]*/u

    # Find all matches
    matches = Regex.scan(url_regex, text, return: :index)

    Enum.map(matches, fn [{start_index, length}] ->
      # Extract the URL string
      url = binary_part(text, start_index, length)

      # Process the URL to remove trailing punctuation
      clean_url =
        case Regex.run(~r/(.*?)([.,!?;:]*)$/, url) do
          [_, url_part, punctuation] when punctuation != "" ->
            url_part

          _ ->
            url
        end

      # Calculate the adjusted length
      adjusted_length = String.length(clean_url)

      %{
        "index" => %{
          "byteStart" => start_index,
          "byteEnd" => start_index + adjusted_length
        },
        "features" => [
          %{
            "$type" => "app.bsky.richtext.facet#link",
            "uri" => clean_url
          }
        ]
      }
    end)
  end

  @doc """
  Extracts hashtag facets from the given text.

  Scans the input text for hashtags and returns their positions along with
  associated features. Hashtags are captured from the '#' until the next 
  whitespace character and are only included if they consist entirely of 
  alphanumeric characters and underscores.

  ## Parameters

    - `text`: A string containing the text to scan for hashtags.

  ## Examples

      iex> Bluesky.Facet.hashtags("Check out the #elixir programming language!")
      [
        %{
          "index" => %{"byteStart" => 14, "byteEnd" => 21},
          "features" => [%{"$type" => "app.bsky.richtext.facet#tag", "tag" => "elixir"}]
        }
      ]
      
      iex> Bluesky.Facet.hashtags("Invalid hashtag: #$invalid")
      []
  """
  def hashtags(text) do
    # Capture hashtags: the # symbol followed by alphanumeric characters and underscores
    # This will stop capturing at the first non-alphanumeric character
    hashtag_regex = ~r/#([a-zA-Z0-9_]+)/u
    hashtags = Regex.scan(hashtag_regex, text)

    Enum.map(hashtags, fn [full_tag, tag_text] ->
      {start_index, length} = :binary.match(text, full_tag)

      %{
        "index" => %{
          "byteStart" => start_index,
          "byteEnd" => start_index + length
        },
        "features" => [
          %{
            "$type" => "app.bsky.richtext.facet#tag",
            "tag" => tag_text
          }
        ]
      }
    end)
  end
end
