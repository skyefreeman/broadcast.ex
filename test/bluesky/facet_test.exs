defmodule Bluesky.FacetTest do
  use ExUnit.Case
  doctest Bluesky.Facet

  describe "links/1" do
    test "extracts links from text" do
      text = "Check out this link: https://example.com and this one: http://elixir-lang.org/"
      
      facets = Bluesky.Facet.links(text)
      
      assert length(facets) == 2
      
      [first, second] = facets
      
      assert get_in(first, ["features", Access.at(0), "$type"]) == "app.bsky.richtext.facet#link"
      assert get_in(first, ["features", Access.at(0), "uri"]) == "https://example.com"
      
      assert get_in(second, ["features", Access.at(0), "$type"]) == "app.bsky.richtext.facet#link"
      assert get_in(second, ["features", Access.at(0), "uri"]) == "http://elixir-lang.org/"
    end
    
    test "returns empty list when no links are present" do
      text = "This text has no links"
      assert Bluesky.Facet.links(text) == []
    end
    
    test "handles links with subdomains" do
      text = "Visit subdomain.example.com/path and api.elixir-lang.org/docs"
      
      facets = Bluesky.Facet.links(text)
      
      # Should not match these since they don't have a protocol
      assert length(facets) == 0
      
      # With protocols added
      text = "Visit https://subdomain.example.com/path and http://api.elixir-lang.org/docs"
      
      facets = Bluesky.Facet.links(text)
      
      assert length(facets) == 2
      
      uris = Enum.map(facets, fn facet -> 
        get_in(facet, ["features", Access.at(0), "uri"]) 
      end)
      
      assert "https://subdomain.example.com/path" in uris
      assert "http://api.elixir-lang.org/docs" in uris
    end
    
    test "excludes trailing punctuation from links" do
      text = "Check this out: https://example.com, and this: https://elixir-lang.org/docs."
      
      facets = Bluesky.Facet.links(text)
      
      assert length(facets) == 2
      
      uris = Enum.map(facets, fn facet -> 
        get_in(facet, ["features", Access.at(0), "uri"]) 
      end)
      
      assert "https://example.com" in uris
      assert "https://elixir-lang.org/docs" in uris
      
      # Verify the position indices
      example_facet = Enum.find(facets, fn facet -> 
        get_in(facet, ["features", Access.at(0), "uri"]) == "https://example.com" 
      end)
      
      example_start = get_in(example_facet, ["index", "byteStart"])
      example_end = get_in(example_facet, ["index", "byteEnd"])
      
      # Make sure we captured only the URL without trailing punctuation
      assert String.slice(text, example_start, example_end - example_start) == "https://example.com"
    end
  end
  
  describe "hashtags/1" do
    test "extracts hashtags from text" do
      text = "I love #elixir and #programming!"
      
      facets = Bluesky.Facet.hashtags(text)
      
      assert length(facets) == 2
      
      [first, second] = facets
      
      assert get_in(first, ["features", Access.at(0), "$type"]) == "app.bsky.richtext.facet#tag"
      assert get_in(first, ["features", Access.at(0), "tag"]) == "elixir"
      
      assert get_in(second, ["features", Access.at(0), "$type"]) == "app.bsky.richtext.facet#tag"
      assert get_in(second, ["features", Access.at(0), "tag"]) == "programming"
    end
    
    test "returns empty list when no hashtags are present" do
      text = "This text has no hashtags"
      assert Bluesky.Facet.hashtags(text) == []
    end
    
    test "only extracts alphanumeric's from hashtags" do
      text = "Valid: #elixir #code123 Invalid: #no-dash #no_special$chars"
      
      facets = Bluesky.Facet.hashtags(text)
      
      assert length(facets) == 4
      
      tags = Enum.map(facets, fn facet -> 
        get_in(facet, ["features", Access.at(0), "tag"]) 
      end)
      
      assert "elixir" in tags
      assert "code123" in tags
      assert "no" in tags
      assert "no_special" in tags
    end
    
    test "captures hashtags until the first non-alphanumeric character" do
      text = "Check out #elixir. And #programming! Also #rust,#go."
      
      facets = Bluesky.Facet.hashtags(text)
      
      assert length(facets) == 4
      
      tags = Enum.map(facets, fn facet -> 
        get_in(facet, ["features", Access.at(0), "tag"]) 
      end)
      
      assert "elixir" in tags
      assert "programming" in tags
      assert "rust" in tags
      assert "go" in tags
      
      # Check for full tag string including the # in index range
      elixir_facet = Enum.find(facets, fn facet -> 
        get_in(facet, ["features", Access.at(0), "tag"]) == "elixir" 
      end)
      
      # Make sure it captured exactly "#elixir"
      assert get_in(elixir_facet, ["index", "byteEnd"]) - get_in(elixir_facet, ["index", "byteStart"]) == 7 # "#elixir" is 7 bytes
    end
    
    test "correctly extracts parts of hyphenated hashtags" do
      text = "#good #also-good #not-good #123ok"
      
      facets = Bluesky.Facet.hashtags(text)
      
      # Should capture the alphanumeric parts: #good, #also, #not, #123ok
      assert length(facets) == 4
      
      tags = Enum.map(facets, fn facet -> 
        get_in(facet, ["features", Access.at(0), "tag"]) 
      end)
      
      assert "good" in tags
      assert "also" in tags
      assert "not" in tags
      assert "123ok" in tags
      
      # Check that we've properly extracted only the alphanumeric part before the hyphen
      also_facet = Enum.find(facets, fn facet -> 
        get_in(facet, ["features", Access.at(0), "tag"]) == "also" 
      end)
      
      also_start = get_in(also_facet, ["index", "byteStart"])
      also_end = get_in(also_facet, ["index", "byteEnd"])
      
      # Making sure we only got "#also" and not "#also-good"
      assert String.slice(text, also_start, also_end - also_start) == "#also"
    end
  end
  
  describe "facets/1" do
    test "combines link and hashtag facets" do
      text = "Check out #elixir at https://elixir-lang.org/ and use the #beam VM"
      
      facets = Bluesky.Facet.facets(text)
      
      assert length(facets) == 3
      
      types = Enum.map(facets, fn facet -> 
        get_in(facet, ["features", Access.at(0), "$type"]) 
      end)
      
      assert Enum.count(types, fn type -> type == "app.bsky.richtext.facet#tag" end) == 2
      assert Enum.count(types, fn type -> type == "app.bsky.richtext.facet#link" end) == 1
      
      values = Enum.map(facets, fn facet ->
        feature = get_in(facet, ["features", Access.at(0)])
        case feature["$type"] do
          "app.bsky.richtext.facet#tag" -> feature["tag"]
          "app.bsky.richtext.facet#link" -> feature["uri"]
        end
      end)
      
      assert "elixir" in values
      assert "beam" in values
      assert "https://elixir-lang.org/" in values
    end
  end
end
