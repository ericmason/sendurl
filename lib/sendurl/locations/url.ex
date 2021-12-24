defmodule Sendurl.Locations.URL do
  use Ecto.Schema
  import Ecto.Changeset

  schema "urls" do
    field :receiver_id, :string
    field :url, :string

    timestamps()
  end

  @doc false
  def changeset(url, attrs) do
    url
    |> cast(attrs, [:url, :receiver_id])
    |> validate_format(:url, ~r/\Ahttps?:\/\/[^\s]+\z/)
    |> validate_required([:url])
  end
end
