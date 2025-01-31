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

  ## Examples

    iex> post_all(%{
    ...>   status: "Hello World!",
    ...>   mastodon_access_token: "your_mastodon_token",
    ...>   bluesky_handle: "your_bluesky_handle",
    ...>   bluesky_password: "your_bluesky_password"
    ...> })
    {:ok, [mastodon_result, bluesky_result]}

  """
  def post_all(
    %{
      status: status,
      mastodon_access_token: mastodon_access_token,
      bluesky_handle: bluesky_handle,
      bluesky_password: bluesky_password
    }
  ) do
    mastodon_result = post_mastodon_status(mastodon_access_token, status)
    bluesky_result = post_bluesky_status(bluesky_handle, bluesky_password, status)
    {:ok, [mastodon_result, bluesky_result]}
  end

  @doc """
  Posts a status update to the Mastodon social media platform.

  ## Parameters

    * `access_token` - The bearer token used for authentication with the Mastodon API.
    * `status` - The string representing the status update to be posted.

  ## Examples

    iex> post_mastodon_status("your_access_token", "Hello, Mastodon!")
    {:ok, response}

  """
  def post_mastodon_status(access_token, status) do
    base_url = "https://mastodon.social/api/v1/statuses"

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Idempotency-Key", status},
      {"Content-Type", "application/json"}
    ]

    params = %{"status" => status}

    post(base_url, params, headers)
  end

  @doc """
  Posts a status update to the Bluesky social network.

  ## Parameters

    * `handle`: a string representing the user identifier on the Bluesky platform.
    * `password`: a string containing the user password for authentication.
    * `status`: a string representing the status update to be posted.

  ## Examples

    iex> post_bluesky_status("your_user_handle", "your_password", "Hello, Mastodon!")
    {:ok, response}
    
  """
  def post_bluesky_status(handle, password, status) do
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

        # post the status
        post(
          "https://bsky.social/xrpc/com.atproto.repo.createRecord",
          %{
            "repo" => handle,
            "collection" => "app.bsky.feed.post",
            "record" => %{
              "text" => status,
              "createdAt" => datetime_now()
            }
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


  # private helpers

  defp datetime_now do
    (DateTime.utc_now()
     |> DateTime.to_iso8601()
     |> String.split(".")
     |> List.first()) <> "Z"
  end

  defp post(url, params, headers) do
    case HTTPoison.post(url, Jason.encode!(params), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        {:error, "Unexpected Response:\n Status code: #{status_code}\n #{response_body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{reason}"}
    end
  end
end
