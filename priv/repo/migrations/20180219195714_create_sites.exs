defmodule ElephantInTheRoom.Repo.Migrations.CreateSites do
  use Ecto.Migration

  def change do
    create table(:sites) do
      add(:name, :string)

      timestamps()
    end
  end
end
