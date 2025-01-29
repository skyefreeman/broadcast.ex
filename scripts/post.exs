defmodule Post do
  
  def main(args \\ System.argv()) do
    # Parse the command line arguments
    {opts, second, third} =
      OptionParser.parse(
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
    if opts[:mastodon_access_token] != nil and
    opts[:status] != nil do
      response =
        Broadcast.post_mastodon_status(
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
      response =
        Broadcast.post_bluesky_status(
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
	
end

Post.main()
