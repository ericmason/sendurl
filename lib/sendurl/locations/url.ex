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
    |> fix_url_changeset
    |> validate_format(:url, ~r/\Ahttps?:\/\/[^\s]+\z/)
    |> validate_format(:receiver_id, ~r/\A[A-Z0-9]{6}\z/)
    |> validate_required([:url, :receiver_id])
  end

  defp fix_url_changeset(changeset) do
    url = fix_url(get_field(changeset, :url, ""))
    changeset 
    |> put_change(:url, url)
  end

  defp fix_url(nil) do nil end
  defp fix_url(url) do
    if String.match?(url, ~r/\A(?!https?:\/\/)\w+/) do
      "https://#{url}"
    else
      url
    end
  end
end
