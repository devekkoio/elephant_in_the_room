defmodule ElephantInTheRoom.Posts.Category do
  use ElephantInTheRoom.Schema
  import Ecto.Changeset
  alias ElephantInTheRoom.Posts.{Category, Post}
  alias ElephantInTheRoom.Sites.Site

  schema "categories" do
    field(:description, :string)
    field(:name, :string)

    belongs_to(:site, Site, foreign_key: :site_id)

    many_to_many(
      :posts,
      Post,
      join_through: "posts_categories",
      on_replace: :delete,
      on_delete: :delete_all
    )

    timestamps()
  end

  @doc false
  def changeset(%Category{} = category, attrs) do
    category
    |> cast(attrs, [:name, :description, :site_id])
    |> validate_required([:name, :description, :site_id], message: "Campo requerido.")
    |> unique_constraint(:name, message: "Ya existe.")
  end
end
