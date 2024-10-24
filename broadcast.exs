#!/usr/bin/env elixir

Mix.install([:httpoison, :jason, :uuid])

defmodule Broadcast do

  def main(args \\ System.argv()) do
    # Parse the command line arguments
    {opts, _, _} = OptionParser.parse(
      args,
      switches: [
	mastodon_access_token: :string,
	bluesky_handle: :string,
	bluesky_password: :string,
	status: :string,
	debug: :boolean
      ]
    )

    # Mastodon
    if opts[:mastodon_access_token] != nil
    and opts[:status] != nil do
      response = post_mastodon_status(
	opts[:mastodon_access_token],
	opts[:status]
      )
      
      IO.puts("Mastodon: ok.")
      
      if opts[:debug] do
	IO.inspect(response)
      end
    else
      IO.puts("Skipping Mastodon.")
    end

    # Bluesky
    if opts[:bluesky_handle] != nil
    and opts[:bluesky_password] != nil
    and opts[:status] != nil do
      response = post_bluesky_status(
	opts[:bluesky_handle],
	opts[:bluesky_password],
	opts[:status]
      )

      case response do
	{:ok, _} ->
	  IO.puts("Bluesky: ok.")
	{:error, response} ->
	  IO.puts("Bluesky: #{response}")
      end
      
      if opts[:debug] do
	IO.inspect(response)
      end
    else
      IO.puts("Skipping Bluesky.")
    end
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
    response = post(
      "https://bsky.social/xrpc/com.atproto.server.createSession",
      %{
	"identifier" => handle,
	"password" => password
      },
      [{"Content-Type", "application/json"}]
    )

    case response do
      {:ok, raw} ->
	json = raw |> Jason.decode!
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

      {:error, raw} ->
	response
    end
  end

  # helpers

  def datetime_now do
    (DateTime.utc_now
    |> DateTime.to_iso8601
    |> String.split(".")
    |> List.first) <> "Z"
  end
  
  def post(url, params, headers) do
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

Broadcast.main()
