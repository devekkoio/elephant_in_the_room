defmodule ElephantInTheRoomWeb.Plugs.SetSite do
  alias ElephantInTheRoom.Repo
  alias ElephantInTheRoom.Sites.Site
  alias Plug.Conn

  def set_site(conn, params) do
    if conn.host != "localhost" do
      case Repo.get_by(Site, host: conn.host) do
        nil ->
          conn

        site ->
          site =
            site
            |> Repo.preload(categories: [], posts: [:tags, :categories, :author], tags: [])

          conn
          |> Conn.assign(:site, site)
      end
    else
      conn
    end
  end
end