defmodule ElephantInTheRoomWeb.Faker.Utils do
  # download the image from source
  defp download_image(source, trials) when trials < 1 do
    raise "can not download #{source}"
  end

  defp download_image(source, trials) do
    result = HTTPoison.request(:get, source, "", [], hackney: [{:follow_redirect, true}])

    case result do
      {:ok, %{body: body}} ->
        body

      _ ->
        download_image(source, trials - 1)
    end
  end

  def download_image(source) do
    download_image(source, 8)
  end

  def fake_image_upload(%{"cover" => cover} = attrs) do
    %{"image" => image} = fake_image_upload(%{"image" => cover})
    %{attrs | "cover" => image}
  end

  def get_image_path() do
    File.ls!("./images")
    |> Enum.random()
    |> (fn image -> "./images/#{image}" end).()
  end

  def fake_image_upload(attrs, format \\ "png") do
    {:ok, file} = Plug.Upload.random_file("gen")
    content = File.read!(get_image_path())
    File.write(file, content)

    uploaded_image = %Plug.Upload{
      path: file,
      content_type: "image/#{format}",
      filename: file |> Path.split() |> List.last() |> (fn name -> "#{name}.#{format}" end).()
    }

    Map.put(attrs, "image", uploaded_image)
  end
end
