defmodule ElephantInTheRoomWeb.Router do
  use ElephantInTheRoomWeb, :router
  import ElephantInTheRoomWeb.Plugs.DomainInspector

  pipeline :auth do
    plug(ElephantInTheRoom.Auth.Pipeline)
  end

  pipeline :ensure_auth do
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:set_site)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", ElephantInTheRoomWeb do
    # Use the default browser stack
    pipe_through([:browser, :auth])

    get("/", SiteController, :public_show)
    get("/login", LoginController, :index)
    post("/login", LoginController, :login)
    get("/logout", LoginController, :logout)
    resources("/users", UserController, only: [:new, :create])
    get("/author/:author_id", AuthorController, :public_show)

    get("/post/:year/:month/:day/:slug", PostController, :public_show)
    get("/category/:category_id", CategoryController, :public_show)
    get("/tag/:tag_id", TagController, :public_show)

    scope "/admin" do
      pipe_through([:on_admin_page, :ensure_auth])
      get("/", AdminController, :index)
      resources("/roles", RoleController)
      resources("/users", UserController, except: [:new, :create])
      resources("/authors", AuthorController)

      resources "/sites", SiteController do
        pipe_through(:load_site_info)
        resources("/categories", CategoryController)
        resources("/posts", PostController)
        resources("/tags", TagController)
      end
    end
  end
end
