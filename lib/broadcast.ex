defmodule Broadcast do
  @moduledoc """
  Broadcast to multiple social media domains simultaneously through a unified interface.
  """

  @doc """
  Posts a given status message to both Mastodon and Bluesky platforms.

  ## Parameters

    The function takes a map containing the necessary parameters for posting:

    * `:status` - a string representing the status message to be posted.
    * `:mastodon_access_token` - the access token for the Mastodon account for authentication.
    * `:bluesky_handle` - the handle (username) of the Bluesky account to post the status.
    * `:bluesky_password` - the password for the Bluesky account for authentication.
    * `:media_paths` - Optional. A list of file paths to images to be uploaded with the status.
    * `:mastodon_reply_id` - Optional. The ID of a Mastodon post to reply to.
    * `:bluesky_reply` - Optional. A map containing details of a Bluesky post to reply to:
      * `:root` - A map with `:uri` and `:cid` of the root (original) post in the thread.
      * `:parent` - A map with `:uri` and `:cid` of the parent post to reply to directly.

  ## Examples

    iex> Broadcast.post_all(%{
    ...>   status: "Hello World!",
    ...>   mastodon_access_token: "your_mastodon_token",
    ...>   bluesky_handle: "your_bluesky_handle",
    ...>   bluesky_password: "your_bluesky_password"
    ...> })
    {:ok, [{:ok, "{\"id\": \"123\"}"}, {:ok, "{\"uri\": \"at://did:123/post/123\"}"}]}

    iex> Broadcast.post_all(%{
    ...>   status: "Hello World with an image!",
    ...>   mastodon_access_token: "your_mastodon_token",
    ...>   bluesky_handle: "your_bluesky_handle",
    ...>   bluesky_password: "your_bluesky_password",
    ...>   media_paths: ["path/to/image.jpg"]
    ...> })
    {:ok, [{:ok, "{\"id\": \"123\"}"}, {:ok, "{\"uri\": \"at://did:123/post/123\"}"}]}

    iex> Broadcast.post_all(%{
    ...>   status: "This is a reply!",
    ...>   mastodon_access_token: "your_mastodon_token",
    ...>   bluesky_handle: "your_bluesky_handle",
    ...>   bluesky_password: "your_bluesky_password",
    ...>   mastodon_reply_id: "109372843234",
    ...>   bluesky_reply: %{
    ...>     root: %{uri: "at://did:123/app.bsky.feed.post/1234", cid: "bafyreic..."},
    ...>     parent: %{uri: "at://did:123/app.bsky.feed.post/1234", cid: "bafyreic..."}
    ...>   }
    ...> })
    {:ok, [{:ok, "{\"id\": \"123\"}"}, {:ok, "{\"uri\": \"at://did:123/post/456\"}"}]}

  """
  def post_all(
        %{
          status: status,
          mastodon_access_token: mastodon_access_token,
          bluesky_handle: bluesky_handle,
          bluesky_password: bluesky_password
        } = params
      ) do
    media_paths = Map.get(params, :media_paths, [])
    mastodon_reply_id = Map.get(params, :mastodon_reply_id)
    bluesky_reply = Map.get(params, :bluesky_reply)

    mastodon_result =
      post_mastodon_status(mastodon_access_token, status, media_paths, mastodon_reply_id)

    bluesky_result =
      post_bluesky_status(bluesky_handle, bluesky_password, status, media_paths, bluesky_reply)

    {:ok, [mastodon_result, bluesky_result]}
  end

  @doc """
  Posts a status update to the Mastodon social media platform.

  ## Parameters

    * `access_token` - The bearer token used for authentication with the Mastodon API.
    * `status` - The string representing the status update to be posted.
    * `media_paths` - Optional list of file paths to images to be uploaded with the status.
    * `in_reply_to_id` - Optional ID of a status to reply to.

  ## Examples

    iex> Broadcast.post_mastodon_status("your_access_token", "Hello, Mastodon!")
    {:ok, "{\"id\": \"123\"}"}

    iex> Broadcast.post_mastodon_status("your_access_token", "Hello, Mastodon!", ["path/to/image.jpg"])
    {:ok, "{\"id\": \"123\"}"}
    
    iex> Broadcast.post_mastodon_status("your_access_token", "This is a reply!", [], "109372843234")
    {:ok, "{\"id\": \"123\"}"}

  """
  def post_mastodon_status(access_token, status, media_paths \\ [], in_reply_to_id \\ nil) do
    base_url = "https://mastodon.social/api/v1/statuses"

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Idempotency-Key", UUID.uuid4()},
      {"Content-Type", "application/json"}
    ]

    # Start with base parameters
    base_params = %{"status" => status}

    # Add in_reply_to_id if provided
    params_with_reply =
      if in_reply_to_id do
        Map.put(base_params, "in_reply_to_id", in_reply_to_id)
      else
        base_params
      end

    # Add media_ids if available
    params =
      case upload_media(access_token, media_paths) do
        {:ok, media_ids} when media_ids != [] ->
          Map.put(params_with_reply, "media_ids", media_ids)

        _ ->
          params_with_reply
      end

    post(base_url, params, headers)
  end

  defp upload_media(_access_token, []), do: {:ok, []}

  defp upload_media(access_token, media_paths) do
    upload_url = "https://mastodon.social/api/v2/media"

    headers = [
      {"Authorization", "Bearer #{access_token}"}
    ]

    media_ids =
      Enum.reduce_while(media_paths, [], fn media_path, acc ->
        case upload_single_media(upload_url, media_path, headers) do
          {:ok, media_id} -> {:cont, [media_id | acc]}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case media_ids do
      {:error, reason} -> {:error, reason}
      ids -> {:ok, Enum.reverse(ids)}
    end
  end

  defp upload_single_media(upload_url, media_path, headers) do
    case File.read(media_path) do
      {:ok, _binary} ->
        # Get the content type based on file extension
        content_type = get_content_type(media_path)

        # Prepare the multipart form
        form =
          {:multipart,
           [
             {:file, media_path,
              {"form-data", [{"name", "file"}, {"filename", Path.basename(media_path)}]},
              [{"Content-Type", content_type}]}
           ]}

        # Upload the media
        case HTTPoison.post(upload_url, form, headers) do
          {:ok, %HTTPoison.Response{status_code: status_code, body: body}}
          when status_code in 200..299 ->
            case Jason.decode(body) do
              {:ok, %{"id" => media_id}} -> {:ok, media_id}
              _ -> {:error, "Failed to parse media upload response"}
            end

          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
            {:error, "Media upload failed with status #{status_code}: #{body}"}

          {:error, %HTTPoison.Error{reason: reason}} ->
            {:error, "HTTP error during media upload: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to read media file: #{reason}"}
    end
  end

  defp get_content_type(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      _ -> "application/octet-stream"
    end
  end

  @doc """
  Posts a status update to the Bluesky social network.

  ## Parameters

    * `handle`: a string representing the user identifier on the Bluesky platform.
    * `password`: a string containing the user password for authentication.
    * `status`: a string representing the status update to be posted.
    * `media_paths`: Optional list of file paths to images to be uploaded with the status. Defaults to an empty list.
    * `reply`: Optional map containing reply information with root and parent posts. Required fields for each:
      * `root`: Map with `:uri` and `:cid` of the root post in the thread.
      * `parent`: Map with `:uri` and `:cid` of the parent post to reply to directly.

  ## Examples

    iex> Broadcast.post_bluesky_status("your_user_handle", "your_password", "Hello, Bluesky!")
    {:ok, "{\"uri\": \"at://did:123/post/123\"}"}

    iex> Broadcast.post_bluesky_status("your_user_handle", "your_password", "Hello with image!", ["path/to/image.jpg"])
    {:ok, "{\"uri\": \"at://did:123/post/123\"}"}
    
    iex> reply_info = %{
    ...>   root: %{uri: "at://did:123/app.bsky.feed.post/1234", cid: "bafyreic..."},
    ...>   parent: %{uri: "at://did:123/app.bsky.feed.post/1234", cid: "bafyreic..."}
    ...> }
    iex> Broadcast.post_bluesky_status("your_user_handle", "your_password", "This is a reply!", [], reply_info)
    {:ok, "{\"uri\": \"at://did:123/post/456\"}"}
    
  """
  def post_bluesky_status(handle, password, status, media_paths \\ [], reply \\ nil) do
    # authenticate
    response =
      post(
        "https://bsky.social/xrpc/com.atproto.server.createSession",
        %{
          "identifier" => handle,
          "password" => password
        },
        [{"Content-Type", "application/json"}]
      )

    case response do
      {:ok, raw} ->
        json = raw |> Jason.decode!()
        access_token = json |> Map.get("accessJwt")
        did = json |> Map.get("did")

        # upload images if any
        images = upload_bluesky_images(access_token, media_paths)

        # prepare record with or without images
        record = %{
          "text" => status,
          "createdAt" => datetime_now(),
          "facets" => Bluesky.Facet.facets(status)
        }

        # Add reply reference if provided
        record =
          if reply do
            # Convert atom keys to string keys in the reply map
            # The root and parent maps should have :uri and :cid keys
            root = %{
              "uri" => reply.root.uri,
              "cid" => reply.root.cid
            }

            parent = %{
              "uri" => reply.parent.uri,
              "cid" => reply.parent.cid
            }

            reply_ref = %{
              "root" => root,
              "parent" => parent
            }

            Map.put(record, "reply", reply_ref)
          else
            record
          end

        # Add image embeds if provided
        record =
          case images do
            [] ->
              record

            image_refs when is_list(image_refs) ->
              Map.put(record, "embed", %{
                "$type" => "app.bsky.embed.images",
                "images" => image_refs
              })
          end

        # post the status
        post(
          "https://bsky.social/xrpc/com.atproto.repo.createRecord",
          %{
            "repo" => did,
            "collection" => "app.bsky.feed.post",
            "record" => record
          },
          [
            {"Authorization", "Bearer #{access_token}"},
            {"Content-Type", "application/json"}
          ]
        )

      {:error, _raw} ->
        response
    end
  end

  defp upload_bluesky_images(_access_token, []), do: []

  defp upload_bluesky_images(access_token, media_paths) do
    Enum.reduce_while(media_paths, [], fn media_path, acc ->
      case upload_bluesky_image(access_token, media_path) do
        {:ok, image_ref} -> {:cont, [image_ref | acc]}
        {:error, _reason} -> {:halt, []}
      end
    end)
    |> Enum.reverse()
  end

  defp upload_bluesky_image(access_token, media_path) do
    case File.read(media_path) do
      {:ok, binary} ->
        content_type = get_content_type(media_path)

        # Upload the blob
        upload_url = "https://bsky.social/xrpc/com.atproto.repo.uploadBlob"

        headers = [
          {"Authorization", "Bearer #{access_token}"},
          {"Content-Type", content_type}
        ]

        case HTTPoison.post(upload_url, binary, headers) do
          {:ok, %HTTPoison.Response{status_code: status_code, body: body}}
          when status_code in 200..299 ->
            case Jason.decode(body) do
              {:ok, %{"blob" => blob}} ->
                # Return the image reference in the format Bluesky expects
                {:ok,
                 %{
                   "alt" => Path.basename(media_path, Path.extname(media_path)),
                   "image" => blob
                 }}

              _ ->
                {:error, "Failed to parse blob upload response"}
            end

          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
            {:error, "Blob upload failed with status #{status_code}: #{body}"}

          {:error, %HTTPoison.Error{reason: reason}} ->
            {:error, "HTTP error during blob upload: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to read media file: #{reason}"}
    end
  end

  # private helpers

  defp datetime_now do
    (DateTime.utc_now()
     |> DateTime.to_iso8601()
     |> String.split(".")
     |> List.first()) <> "Z"
  end

  defp post(url, params, headers) do
    encoded = Jason.encode!(params, escape: :unicode_safe)
    response = HTTPoison.post(url, encoded, headers)

    case response do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        {:error, "Unexpected Response:\n Status code: #{status_code}\n #{response_body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{reason}"}
    end
  end
end
