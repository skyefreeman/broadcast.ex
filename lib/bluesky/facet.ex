defmodule Bluesky.Facet do
  @moduledoc """
  Helper module for interfacing with the Bluesky Facet API:  https://docs.bsky.app/docs/advanced-guides/post-richtext
  """

  @doc """
  Extracts link facets from the given text.

  Scans the input text for URLs and returns their positions along with
  associated features.

  ## Parameters

    - `text`: A string containing the text to scan for links.

  ## Examples

      iex> MyModule.link_facets("Visit us at https://example.com.")
      [
        %{
          "index" => %{"byteStart" => 10, "byteEnd" => 30},
          "features" => [%{"$type" => "app.bsky.richtext.facet#link", "uri" => "https://example.com"}]
        }
      ]
  """
  def links(text) do
    url_regex = ~r/http[s]?:\/\/[^\s]+/u
    links = Regex.scan(url_regex, text)

    Enum.map(links, fn [str] ->
      {start_index, length} = :binary.match(text, str)

      %{
        "index" => %{
          "byteStart" => start_index,
          "byteEnd" => start_index + length
        },
        "features" => [
          %{
            "$type" => "app.bsky.richtext.facet#link",
            "uri" => str
          }
        ]
      }
    end)
  end
end
