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

  describe "post_mastodon_status/3" do
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
  end

  describe "post_bluesky_status/4" do
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
  end
end
