defmodule BroadcastTest do
  use ExUnit.Case
  import Mock

  describe "post_all/1" do
    test "successfully posts to all platforms" do
      with_mocks([
        {HTTPoison, [],
         [
           post: fn
             # Mastodon mock
             "https://mastodon.social/api/v1/statuses", _, _ ->
               {:ok,
                %HTTPoison.Response{
                  status_code: 200,
                  body: ~s({"id": "123"})
                }}

             # Bluesky mocks
             "https://bsky.social/xrpc/com.atproto.server.createSession", _, _ ->
               {:ok,
                %HTTPoison.Response{
                  status_code: 200,
                  body: ~s({"accessJwt": "token", "did": "did:123"})
                }}

             "https://bsky.social/xrpc/com.atproto.repo.createRecord", _, _ ->
               {:ok,
                %HTTPoison.Response{
                  status_code: 200,
                  body: ~s({"uri": "at://did:123/post/123"})
                }}
           end
         ]}
      ]) do
        {:ok, [mastodon_result, bluesky_result]} =
          Broadcast.post_all(%{
            status: "Test post",
            mastodon_access_token: "test_token",
            bluesky_handle: "test_handle",
            bluesky_password: "test_password"
          })

        assert {:ok, "{\"id\": \"123\"}"} = mastodon_result
        assert {:ok, "{\"uri\": \"at://did:123/post/123\"}"} = bluesky_result
      end
    end
  end

  describe "post_mastodon_status/4" do
    test "successfully posts to Mastodon" do
      with_mock HTTPoison,
        post: fn _, _, _ ->
          {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"id": "123"})}}
        end do
        result = Broadcast.post_mastodon_status("test_token", "Hello Mastodon")
        assert {:ok, "{\"id\": \"123\"}"} = result
      end
    end

    test "handles posting with media" do
      with_mocks([
        {HTTPoison, [],
         [
           post: fn
             # Media upload mock
             "https://mastodon.social/api/v2/media", _, _ ->
               {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"id": "media123"})}}

             # Status post mock
             "https://mastodon.social/api/v1/statuses", _, _ ->
               {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"id": "123"})}}
           end
         ]},
        {File, [], [read: fn _ -> {:ok, "binary data"} end]}
      ]) do
        result = Broadcast.post_mastodon_status("test_token", "Post with media", ["test.jpg"])
        assert {:ok, "{\"id\": \"123\"}"} = result
      end
    end

    test "handles errors" do
      with_mock HTTPoison,
        post: fn _, _, _ ->
          {:ok, %HTTPoison.Response{status_code: 401, body: "Unauthorized"}}
        end do
        result = Broadcast.post_mastodon_status("invalid_token", "Hello")
        assert {:error, "Unexpected Response:\n Status code: 401\n Unauthorized"} = result
      end
    end

    test "properly includes reply parameter" do
      with_mock HTTPoison,
        post: fn url, body, _ ->
          # Make sure we're calling the status endpoint
          assert url == "https://mastodon.social/api/v1/statuses"

          # Parse the body and check that in_reply_to_id is included
          decoded = Jason.decode!(body)
          assert decoded["status"] == "This is a reply"
          assert decoded["in_reply_to_id"] == "109372843234"

          {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"id": "456"})}}
        end do
        result =
          Broadcast.post_mastodon_status("test_token", "This is a reply", [], "109372843234")

        assert {:ok, "{\"id\": \"456\"}"} = result
      end
    end
  end

  describe "post_bluesky_status/5" do
    test "successfully posts to Bluesky" do
      with_mocks([
        {HTTPoison, [],
         [
           post: fn
             # Auth mock
             "https://bsky.social/xrpc/com.atproto.server.createSession", _, _ ->
               {:ok,
                %HTTPoison.Response{
                  status_code: 200,
                  body: ~s({"accessJwt": "token", "did": "did:123"})
                }}

             # Post mock
             "https://bsky.social/xrpc/com.atproto.repo.createRecord", _, _ ->
               {:ok,
                %HTTPoison.Response{status_code: 200, body: ~s({"uri": "at://did:123/post/123"})}}
           end
         ]}
      ]) do
        result = Broadcast.post_bluesky_status("test_handle", "test_password", "Hello Bluesky")
        assert {:ok, "{\"uri\": \"at://did:123/post/123\"}"} = result
      end
    end

    test "handles posting with media" do
      with_mocks([
        {HTTPoison, [],
         [
           post: fn
             # Auth mock
             "https://bsky.social/xrpc/com.atproto.server.createSession", _, _ ->
               {:ok,
                %HTTPoison.Response{
                  status_code: 200,
                  body: ~s({"accessJwt": "token", "did": "did:123"})
                }}

             # Blob upload mock
             "https://bsky.social/xrpc/com.atproto.repo.uploadBlob", _, _ ->
               {:ok,
                %HTTPoison.Response{
                  status_code: 200,
                  body: ~s({"blob": {"$type": "blob", "ref": {"$link": "bafyreib"}}})
                }}

             # Post mock
             "https://bsky.social/xrpc/com.atproto.repo.createRecord", _, _ ->
               {:ok,
                %HTTPoison.Response{status_code: 200, body: ~s({"uri": "at://did:123/post/123"})}}
           end
         ]},
        {File, [], [read: fn _ -> {:ok, "binary data"} end]}
      ]) do
        result =
          Broadcast.post_bluesky_status("test_handle", "test_password", "Hello with image", [
            "test.jpg"
          ])

        assert {:ok, "{\"uri\": \"at://did:123/post/123\"}"} = result
      end
    end

    test "handles authentication error" do
      with_mock HTTPoison,
        post: fn _, _, _ ->
          {:ok, %HTTPoison.Response{status_code: 401, body: "Invalid password"}}
        end do
        result = Broadcast.post_bluesky_status("test_handle", "wrong_password", "Hello")
        assert {:error, "Unexpected Response:\n Status code: 401\n Invalid password"} = result
      end
    end

    test "properly formats reply references" do
      with_mocks([
        {HTTPoison, [],
         [
           post: fn
             # Auth mock
             "https://bsky.social/xrpc/com.atproto.server.createSession", _, _ ->
               {:ok,
                %HTTPoison.Response{
                  status_code: 200,
                  body: ~s({"accessJwt": "token", "did": "did:123"})
                }}

             # Post mock with reply check
             "https://bsky.social/xrpc/com.atproto.repo.createRecord", body, _ ->
               # Decode JSON body and verify the reply structure
               decoded = Jason.decode!(body)
               record = decoded["record"]

               assert decoded["repo"] == "did:123"
               assert decoded["collection"] == "app.bsky.feed.post"
               assert record["text"] == "This is a reply"

               # Check reply structure
               reply = record["reply"]
               assert reply["root"]["uri"] == "at://did:123/app.bsky.feed.post/original"
               assert reply["root"]["cid"] == "bafyreihg6tz"
               assert reply["parent"]["uri"] == "at://did:123/app.bsky.feed.post/parent"
               assert reply["parent"]["cid"] == "bafyreiabc123"

               {:ok,
                %HTTPoison.Response{status_code: 200, body: ~s({"uri": "at://did:123/post/456"})}}
           end
         ]}
      ]) do
        reply_info = %{
          root: %{uri: "at://did:123/app.bsky.feed.post/original", cid: "bafyreihg6tz"},
          parent: %{uri: "at://did:123/app.bsky.feed.post/parent", cid: "bafyreiabc123"}
        }

        result =
          Broadcast.post_bluesky_status(
            "test_handle",
            "test_password",
            "This is a reply",
            [],
            reply_info
          )

        assert {:ok, "{\"uri\": \"at://did:123/post/456\"}"} = result
      end
    end
  end

  describe "post_all/1 with replies" do
    test "posts replies to all platforms" do
      with_mocks([
        {HTTPoison, [],
         [
           post: fn
             # Mastodon mock
             "https://mastodon.social/api/v1/statuses", mastodon_body, _ ->
               decoded = Jason.decode!(mastodon_body)
               assert decoded["status"] == "This is a reply!"
               assert decoded["in_reply_to_id"] == "109372843234"

               {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"id": "456"})}}

             # Bluesky auth mock
             "https://bsky.social/xrpc/com.atproto.server.createSession", _, _ ->
               {:ok,
                %HTTPoison.Response{
                  status_code: 200,
                  body: ~s({"accessJwt": "token", "did": "did:123"})
                }}

             # Bluesky post mock
             "https://bsky.social/xrpc/com.atproto.repo.createRecord", bluesky_body, _ ->
               decoded = Jason.decode!(bluesky_body)
               record = decoded["record"]
               reply = record["reply"]

               assert record["text"] == "This is a reply!"
               assert reply["root"]["uri"] == "at://did:123/app.bsky.feed.post/original"
               assert reply["parent"]["cid"] == "bafyreiabc123"

               {:ok,
                %HTTPoison.Response{status_code: 200, body: ~s({"uri": "at://did:123/post/789"})}}
           end
         ]}
      ]) do
        bluesky_reply = %{
          root: %{uri: "at://did:123/app.bsky.feed.post/original", cid: "bafyreihg6tz"},
          parent: %{uri: "at://did:123/app.bsky.feed.post/parent", cid: "bafyreiabc123"}
        }

        {:ok, [mastodon_result, bluesky_result]} =
          Broadcast.post_all(%{
            status: "This is a reply!",
            mastodon_access_token: "test_token",
            bluesky_handle: "test_handle",
            bluesky_password: "test_password",
            mastodon_reply_id: "109372843234",
            bluesky_reply: bluesky_reply
          })

        assert {:ok, "{\"id\": \"456\"}"} = mastodon_result
        assert {:ok, "{\"uri\": \"at://did:123/post/789\"}"} = bluesky_result
      end
    end
  end
end
