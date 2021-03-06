defmodule ElephantInTheRoom.Posts.Post do
  use ElephantInTheRoom.Schema
  import Ecto.Changeset
  alias Ecto.{Changeset, UUID}
  alias ElephantInTheRoom.{Posts, Posts.Category, Posts.Post, Posts.Tag}
  alias ElephantInTheRoom.{Repo, Sites}
  alias ElephantInTheRoom.Sites.{Author, Magazine, Markdown, Site}
  alias ElephantInTheRoomWeb.Uploaders.Image

  schema "posts" do
    field(:title, :string)
    field(:slug, :string)
    field(:abstract, :string)
    field(:type, :string)
    field(:show, :boolean)
    field(:media, :string)
    field(:content, :string)
    field(:rendered_content, :string)
    field(:cover, :string)
    field(:thumbnail, :string)
    field(:featured_level, :integer, default: 0)

    belongs_to(:site, Site, foreign_key: :site_id)
    belongs_to(:author, Author, foreign_key: :author_id, on_replace: :nilify)
    belongs_to(:magazine, Magazine)

    many_to_many(
      :categories,
      Category,
      join_through: "posts_categories",
      on_replace: :delete,
      on_delete: :delete_all
    )

    many_to_many(
      :tags,
      Tag,
      join_through: "posts_tags",
      on_replace: :delete,
      on_delete: :delete_all
    )

    timestamps()
  end

  @doc false
  def changeset(%Post{} = post, attrs) do
    new_attrs =
      attrs
      |> parse_date()
      |> put_site_id()

    post
    |> cast(new_attrs, [
      :title,
      :content,
      :slug,
      :type,
      :show,
      :media,
      :inserted_at,
      :abstract,
      :site_id,
      :author_id,
      :magazine_id,
      :featured_level,
      :thumbnail
    ])
    |> validate_required_site_or_magazine
    |> validate_abstract_max_length(new_attrs, 30)
    |> do_put_assoc(:tags, attrs)
    |> do_put_assoc(:categories, attrs)
    |> validate_required([:title, :type])
    |> validate_required_content(attrs)
    |> check_post_type()
    |> Markdown.put_rendered_content()
    |> put_media_content(attrs)
    |> unique_slug_constraint
    |> store_cover(attrs)
    |> set_thumbnail(attrs)
  end

  defp put_media_content(%Changeset{} = changeset, %{"media" => "", "type" => type}) do
    case type do
      "text" ->
        changeset

      "audio" ->
        add_error(changeset, :media, "Debe agregar un enlace a un audio de Soundcloud")

      "video" ->
        add_error(changeset, :media, "Debe agregar un enlace a un video de Youtube o Vimeo")
    end
  end

  defp put_media_content(%Changeset{} = changeset, %{"type" => type, "media" => media})
       when type != "text" do
    with {:ok, media_properties} <- OEmbed.for(media),
         true <- valid_provider?(media_properties.provider_name, type),
         {:ok, response} <- HTTPoison.get(media_properties.thumbnail_url) do
      changeset
      |> put_iframe(media_properties.html)
      |> put_media_thumbnail(response.body)
    else
      _ ->
        add_error(
          changeset,
          :media,
          "Debe agregar un enlace a un video de Youtube/Vimeo o un audio de SoundCloud"
        )
    end
  end

  defp put_media_content(%Changeset{} = changeset, _attrs), do: changeset

  defp put_media_thumbnail(%Changeset{} = changeset, thumbnail) do
    {:ok, filename} = Plug.Upload.random_file("thumbnail")
    File.write(filename, thumbnail)

    upload = %Plug.Upload{
      path: filename,
      content_type: "image/jpg",
      filename: UUID.generate()
    }

    {:ok, image_name} = Image.store(upload)
    Changeset.put_change(changeset, :thumbnail, "/images/#{image_name}")
  end

  defp put_iframe(%Changeset{} = changeset, iframe) do
    new_content =
      changeset
      |> get_field(:rendered_content)
      |> (fn rendered_content -> "#{iframe} <br/><br/> #{rendered_content}" end).()

    Changeset.put_change(changeset, :rendered_content, new_content)
  end

  defp valid_provider?(provider, "video"), do: Enum.member?(["Youtube", "Vimeo"], provider)
  defp valid_provider?(provider, "audio"), do: Enum.member?(["SoundCloud"], provider)

  defp validate_abstract_max_length(changeset, %{"abstract" => abstract}, max) do
    number_of_words =
      abstract
      |> String.split()
      |> length()

    if number_of_words <= max,
      do: changeset,
      else: add_error(changeset, :abstract, "The abstract should contain 30 words or less")
  end

  defp validate_abstract_max_length(changeset, _attrs, _max), do: changeset

  defp check_post_type(changeset) do
    case get_field(changeset, :magazine_id) do
      nil ->
        changeset

      _magazine_id ->
        if get_field(changeset, :type) != "text",
          do: add_error(changeset, :type, "Magazine posts can't be of type Audio or Video"),
          else: changeset
    end
  end

  def validate_required_content(%Changeset{} = changeset, %{"cover" => nil}) do
    changeset
  end

  def validate_required_content(%Changeset{} = changeset, %{"thumbnail" => nil}) do
    changeset
  end

  def validate_required_content(%Changeset{} = changeset, attrs) do
    with {:ok, "text"} <- Map.fetch(attrs, "type"),
         {:ok, content} when content != "" <- Map.fetch(attrs, "content") do
      changeset
    else
      {:ok, type} when type == "audio" or type == "video" ->
        changeset

      _reason ->
        add_error(changeset, :content, "Debe ingresar contenido")
    end
  end

  def validate_required_site_or_magazine(changeset) do
    case get_field(changeset, :site_id) do
      nil ->
        case get_field(changeset, :magazine_id) do
          nil ->
            add_error(changeset, :site_id, "Site does not exist")

          _magazine_id ->
            changeset
        end

      _site_id ->
        case get_field(changeset, :magazine_id) do
          nil ->
            changeset

          _magazine_id ->
            add_error(changeset, :site_id, "Post can't belong to site and magazine")
        end
    end
  end

  def do_put_assoc(%Changeset{valid?: false} = changeset, _assoc, _attrs) do
    changeset
  end

  def do_put_assoc(changeset, assoc, attrs) do
    site_id =
      case get_field(changeset, :site_id) do
        nil ->
          case get_field(changeset, :magazine_id) do
            nil ->
              nil

            magazine_id ->
              magazine = Sites.get_magazine(magazine_id)
              magazine.site_id
          end

        site_id ->
          site_id
      end

    case assoc do
      :tags ->
        put_assoc(changeset, :tags, parse_tags(site_id, attrs))

      :categories ->
        put_assoc(changeset, :categories, parse_categories(site_id, attrs))
    end
  end

  def put_site_id(%{site_name: site_name}) do
    Sites.get_site_by_name!(site_name)
  end

  def put_site_id(attrs), do: attrs

  def unique_slug_constraint(changeset) do
    put_slugified_title(changeset)
    |> unique_constraint(:slug, name: :slug_unique_index)
  end

  def store_cover(%Changeset{valid?: false} = changeset, _attrs) do
    changeset
  end

  def store_cover(%Changeset{} = changeset, %{"cover" => nil}) do
    put_change(changeset, :cover, nil)
  end

  def store_cover(%Changeset{} = changeset, %{"cover" => _cover, "type" => type})
      when type != "text" do
    add_error(changeset, :cover, "Solo los articulos de tipo texto pueden tener portada")
  end

  def store_cover(%Changeset{} = changeset, %{"cover" => cover}) do
    {:ok, cover_name} = Image.store(%{cover | filename: UUID.generate()})

    put_change(changeset, :cover, "/images/" <> cover_name)
  end

  def store_cover(%Changeset{} = changeset, _attrs) do
    changeset
  end

  def set_thumbnail(%Changeset{valid?: false} = changeset, _attrs), do: changeset

  def set_thumbnail(%Changeset{} = changeset, %{"thumbnail" => nil}) do
    put_change(changeset, :thumbnail, nil)
  end

  def set_thumbnail(%Changeset{} = changeset, %{"type" => "text"}) do
    url =
      case get_field(changeset, :cover) do
        nil ->
          case Regex.run(~r/src="\S+"/, get_field(changeset, :rendered_content)) do
            nil ->
              get_default_image(changeset)

            [img] ->
              img
              |> String.split("\"")
              |> Enum.at(1)
          end

        cover ->
          cover
      end

    put_change(changeset, :thumbnail, url)
  end

  def set_thumbnail(%Changeset{} = changeset, _attrs), do: changeset

  def put_slugified_title(%Changeset{valid?: valid?} = changeset)
      when not valid? do
    changeset
  end

  def put_slugified_title(%Changeset{} = changeset) do
    slug = get_field(changeset, :slug)

    slug =
      if slug == nil || String.length(slug) == 0 do
        get_field(changeset, :title) |> Posts.to_slug()
      else
        slug
      end

    put_change(changeset, :slug, slug)
  end

  def parse_categories(site_id, params) do
    (params["categories"] || [])
    |> Enum.reject(fn s -> s == "" end)
    |> Enum.map(fn name -> get_category(name, site_id) end)
  end

  defp get_category(name, site_id) do
    Repo.get_by!(Category, name: name, site_id: site_id)
  end

  defp parse_tags(site_id, params) do
    (params["tags"] || [])
    |> Enum.reject(fn s -> s == "" end)
    |> Enum.uniq()
    |> Enum.map(&get_or_insert_tag(&1, site_id))
  end

  def get_or_insert_tag(name, site_id) do
    inserted_tag =
      Repo.insert(
        %Tag{name: name, site_id: site_id, color: "686868"},
        on_conflict: :nothing
      )

    case inserted_tag do
      %{id: id} when id != nil ->
        inserted_tag

      _ ->
        Repo.get_by!(Tag, name: name, site_id: site_id)
    end
  end

  defp parse_date(%{"date" => date, "hour" => hour} = attrs) do
    [h, m, s] =
      hour
      |> Enum.map(fn {_, v} -> if String.length(v) == 1, do: "0" <> v, else: v end)

    iso_hour = %{hour: h, minute: m, second: s}
    date_string = "#{date} #{iso_hour.hour}:#{iso_hour.minute}:#{iso_hour.second}"
    {:ok, datetime} = NaiveDateTime.from_iso8601(date_string)

    Map.put(attrs, "inserted_at", datetime)
  end

  defp parse_date(attrs), do: attrs

  def increase_views_for_popular_by_1(%Post{id: post_id, site_id: site_id} = post) do
    Redix.command(:redix, ["ZINCRBY", "site:#{site_id}", 1, post_id])
    post
  end

  def get_default_image(%Changeset{} = changeset) do
    case get_field(changeset, :site_id) do
      nil ->
        magazine = Sites.get_magazine(get_field(changeset, :magazine_id), [:site])
        magazine.site.post_default_image

      site_id ->
        {:ok, site} = Sites.get_site(site_id)
        site.post_default_image
    end
  end
end
