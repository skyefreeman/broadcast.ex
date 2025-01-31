defmodule Broadcast do
  @moduledoc """
  Documentation for `Broadcast`.
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
