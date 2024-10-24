#!/usr/bin/env elixir

Mix.install([:httpoison, :jason, :uuid])

# DONE: externalize api key
# DONE: externalize status

defmodule Broadcast do

  def main(args \\ System.argv()) do
    # Parse the command line arguments
    {opts, _, _} = OptionParser.parse(
      args,
      switches: [
	mastodon_access_token: :string,
	status: :string,
	debug: :boolean
      ]
    )
    
    if opts[:mastodon_access_token] != nil and opts[:status] != nil do
      response = post_mastodon_status(
	opts[:mastodon_access_token],
	opts[:status]
      )
      
      IO.puts("Mastodon: ok.")
      
      if opts[:debug] do
	IO.inspect(response)
      end
    else
      IO.puts("Skipping Mastodon. Missing options.")
    end

    
    # TODO bluesky
    post_bluesky_status()
    #
    # if opts[:mastodon_access_token] != nil and opts[:status] != nil do
    #   post_mastodon_status(
    # 	opts[:mastodon_access_token],
    # 	opts[:status]
    #   )
    # else
    #   IO.puts("Skipping Mastodon. Missing opts.")
    # end

    # TODO threads
    #
    # if opts[:mastodon_access_token] != nil and opts[:status] != nil do
    #   post_mastodon_status(
    # 	opts[:mastodon_access_token],
    # 	opts[:status]
    #   )
    # else
    #   IO.puts("Skipping Mastodon. Missing opts.")
    # end

  end

  def post_mastodon_status(access_token, status) do
    
    base_url = "https://mastodon.social/api/v1/statuses"
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Idempotency-Key", status},
      {"Content-Type", "application/json"}
    ]
    params = %{"status" => status}

    case HTTPoison.post(base_url, Jason.encode!(params), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
	{:ok, response_body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
	{:error, "Failed to post status. Status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
	{:error, "HTTP error: #{reason}"}
    end
  end

  
end

Broadcast.main()
