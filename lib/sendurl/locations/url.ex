defmodule Sendurl.Locations.URL do
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

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
    |> validate_format(:receiver_id, ~r/\A[A-Z0-9]{6}\z/)
    |> validate_required([:url, :receiver_id])
  end

  def url?(nil), do: false
  def url?(value) do
    String.match?(value, ~r/\Ahttps?:\/\/\S+\z/) or
      String.match?(value, ~r/\A[\w-]+(\.[\w-]+)+(\/\S*)?\z/)
  end

  defp fix_url_changeset(changeset) do
    url = normalize_url(get_field(changeset, :url, ""))
    receiver_id = fix_receiver_id(get_field(changeset, :receiver_id, ""))
    changeset
    |> put_change(:url, url)
    |> put_change(:receiver_id, receiver_id)
  end

  defp fix_receiver_id(nil) do nil end
  defp fix_receiver_id(receiver_id) do
    String.upcase(receiver_id)
  end

  defp normalize_url(nil), do: nil
  defp normalize_url(value) do
    if url?(value) and not String.match?(value, ~r/\Ahttps?:\/\//) do
      "https://#{value}"
    else
      value
    end
  end
end
