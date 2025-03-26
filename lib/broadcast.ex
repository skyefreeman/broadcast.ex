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

  ## Examples

    iex> post_all(%{
    ...>   status: "Hello World!",
    ...>   mastodon_access_token: "your_mastodon_token",
    ...>   bluesky_handle: "your_bluesky_handle",
    ...>   bluesky_password: "your_bluesky_password"
    ...> })
    {:ok, [mastodon_result, bluesky_result]}

    iex> post_all(%{
    ...>   status: "Hello World with an image!",
    ...>   mastodon_access_token: "your_mastodon_token",
    ...>   bluesky_handle: "your_bluesky_handle",
    ...>   bluesky_password: "your_bluesky_password",
    ...>   media_paths: ["path/to/image.jpg"]
    ...> })
    {:ok, [mastodon_result, bluesky_result]}

  """
  def post_all(%{
        status: status,
        mastodon_access_token: mastodon_access_token,
        bluesky_handle: bluesky_handle,
        bluesky_password: bluesky_password
      } = params) do
    media_paths = Map.get(params, :media_paths, [])
    mastodon_result = post_mastodon_status(mastodon_access_token, status, media_paths)
    bluesky_result = post_bluesky_status(bluesky_handle, bluesky_password, status, media_paths)
    {:ok, [mastodon_result, bluesky_result]}
  end

  @doc """
  Posts a status update to the Mastodon social media platform.

  ## Parameters

    * `access_token` - The bearer token used for authentication with the Mastodon API.
    * `status` - The string representing the status update to be posted.
    * `media_paths` - Optional list of file paths to images to be uploaded with the status.

  ## Examples

    iex> post_mastodon_status("your_access_token", "Hello, Mastodon!")
    {:ok, response}

    iex> post_mastodon_status("your_access_token", "Hello, Mastodon!", ["path/to/image.jpg"])
    {:ok, response}

  """
  def post_mastodon_status(access_token, status, media_paths \\ []) do
    base_url = "https://mastodon.social/api/v1/statuses"
    
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Idempotency-Key", UUID.uuid4()},
      {"Content-Type", "application/json"}
    ]

    params =
      case upload_media(access_token, media_paths) do
        {:ok, media_ids} when media_ids != [] ->
          %{"status" => status, "media_ids" => media_ids}
        _ ->
          %{"status" => status}
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
      {:ok, binary} ->
        # Get the content type based on file extension
        content_type = get_content_type(media_path)
        
        # Prepare the multipart form
        form = 
          {:multipart, [
            {:file, media_path, 
              {"form-data", [{"name", "file"}, {"filename", Path.basename(media_path)}]},
              [{"Content-Type", content_type}]}
          ]}
        
        # Upload the media
        case HTTPoison.post(upload_url, form, headers) do
          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} when status_code in 200..299 ->
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

  ## Examples

    iex> post_bluesky_status("your_user_handle", "your_password", "Hello, Bluesky!")
    {:ok, response}

    iex> post_bluesky_status("your_user_handle", "your_password", "Hello with image!", ["path/to/image.jpg"])
    {:ok, response}
    
  """
  def post_bluesky_status(handle, password, status, media_paths \\ []) do
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
          "facets" => Bluesky.Facet.links(status)
        }

        record = 
          case images do
            [] -> record
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
          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} when status_code in 200..299 ->
            case Jason.decode(body) do
              {:ok, %{"blob" => blob}} -> 
                # Return the image reference in the format Bluesky expects
                {:ok, %{
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
    encoded = Jason.encode!(params, [escape: :unicode_safe])
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
