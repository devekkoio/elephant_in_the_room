defmodule ElephantInTheRoomWeb.CategoryController do
  use ElephantInTheRoomWeb, :controller

  alias ElephantInTheRoom.Sites
  alias ElephantInTheRoom.Sites.Category
  alias ElephantInTheRoom.Repo

  def index(%{assigns: %{site: site}} = conn, _) do
    categories = Sites.list_categories(site)
    render(conn, "index.html", categories: categories, site: site)
  end

  def new(%{assigns: %{site: site}} = conn, _) do
    changeset =
      %Category{site_id: site.id}
      |> Sites.change_category()

    render(conn, "new.html", changeset: changeset, site: site)
  end

  def create(%{assigns: %{site: site}} = conn, %{"category" => category_params}) do
    case Sites.create_category(site, category_params) do
      {:ok, category} ->
        conn
        |> put_flash(:info, "Category created successfully.")
        |> redirect(to: site_category_path(conn, :show, site, category))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset, site: site)
    end
  end

  def show(%{assigns: %{site: site}} = conn, %{"id" => id}) do
    category = Sites.get_category!(id)
    render(conn, "show.html", category: category, site: site)
  end

  def public_show(%{assigns: %{site: site}} = conn,
                  %{"category_id" => id}) do
    category = Sites.get_category!(id)
    |> Repo.preload(:posts)
    render(conn, "public_show.html", category: category, site: site)
  end

  def edit(%{assigns: %{site: site}} = conn, %{"id" => id}) do
    category = Sites.get_category!(site, id)
    changeset = Sites.change_category(category)
    render(conn, "edit.html", site: site, category: category, changeset: changeset)
  end

  def update(%{assigns: %{site: site}} = conn,
    %{"id" => id, "category" => category_params}) do
    category = Sites.get_category!(id)

    case Sites.update_category(category, category_params) do
      {:ok, category} ->
        conn
        |> put_flash(:info, "Category updated successfully.")
        |> redirect(to: site_category_path(conn, :show, site, category))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", category: category, changeset: changeset)
    end
  end

  def delete(%{assigns: %{site: site}} = conn, %{"id" => id}) do
    category = Sites.get_category!(id)
    {:ok, _category} = Sites.delete_category(category)

    conn
    |> put_flash(:info, "Category deleted successfully.")
    |> redirect(to: site_category_path(conn, :index, site))
  end
end