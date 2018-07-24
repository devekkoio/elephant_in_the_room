defmodule ElephantInTheRoom.Sites.Site do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset
  alias ElephantInTheRoomWeb.{SiteView, Uploaders.Image, Utils.Utils}
  alias ElephantInTheRoom.Sites.{Site, Category, Post, Tag, Author}

  schema "sites" do
    field(:name, :string)
    field(:host, :string)
    field(:image, :string)
    field(:description, :string)
    field(:favicon, :string)
    field(:title, :string)

    has_many(:categories, Category, on_delete: :delete_all)
    has_many(:posts, Post, on_delete: :delete_all)
    has_many(:tags, Tag, on_delete: :delete_all)
    many_to_many(:authors, Author, join_through: Post)

    timestamps()
  end

  @doc false
  def changeset(%Site{} = site, attrs) do
    site
    |> cast(attrs, [:name, :host, :description, :title])
    |> validate_required([:name, :host])
    |> unique_constraint(:name)
    |> unique_constraint(:host)
    |> store_image(attrs)
    |> validate_favicon(attrs)
    |> check_title(attrs)
  end

  def check_title(%Changeset{} = changeset, %{"title" => _title}), do: changeset

  def check_title(%Changeset{} = changeset, %{"name" => name}),
    do: Map.put(changeset, :title, name)

  def check_title(%Changeset{} = changeset, _attrs), do: changeset

  def store_image(%Changeset{valid?: false} = changeset, _attrs) do
    changeset
  end

  def store_image(%Changeset{} = changeset, %{"image" => nil}),
    do: put_change(changeset, :image, nil)

  def store_image(%Changeset{} = changeset, %{"image" => image}) do
    {:ok, image_name} = Image.store(%{image | filename: Ecto.UUID.generate()})

    put_change(changeset, :image, "/images/#{image_name}")
  end

  def store_image(%Changeset{} = changeset, _attrs), do: changeset

  def validate_favicon(%Changeset{valid?: false} = changeset, _attrs) do
    changeset
  end

  def validate_favicon(%Changeset{} = changeset, %{"favicon" => nil}),
    do: put_change(changeset, :favicon, nil)

  def validate_favicon(
        %Changeset{} = changeset,
        %{"favicon" => %Plug.Upload{content_type: ct} = favicon}
      ) do
    if valid_favicon?(ct) do
      {:ok, favicon_name} = Image.store(%{favicon | filename: Ecto.UUID.generate()})

      put_change(changeset, :favicon, "/images/#{favicon_name}")
    else
      Changeset.add_error(changeset, :favicon, "El icono debe tener extensión .ico")
    end
  end

  def validate_favicon(%Changeset{} = changeset, _attrs), do: changeset

  def generate_og_meta(conn) do
    [url, image] =
      [SiteView.show_site_link(conn), conn.assigns.site.image]
      |> Enum.map(fn path -> Utils.generate_absolute_url(path, conn) end)

    %{
      url: url,
      type: "website",
      title: "#{conn.assigns.site.name}",
      description: conn.assigns.site.description,
      image: image
    }
  end

  defp valid_favicon?("image/vnd.microsoft.icon"), do: true
  defp valid_favicon?("image/x-icon"), do: true
  defp valid_favicon?(_content_type), do: false
end
