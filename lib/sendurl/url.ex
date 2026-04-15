defmodule Sendurl.URL do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:receiver_id, :string)
    field(:url, :string)
  end

  def changeset(url, attrs) do
    url
    |> cast(attrs, [:url, :receiver_id])
    |> normalize
    |> validate_format(:receiver_id, ~r/\A[A-Z0-9]{6}\z/)
    |> validate_required([:url, :receiver_id])
  end

  def url?(nil), do: false

  def url?(value) do
    String.match?(value, ~r/\Ahttps?:\/\/\S+\z/) or
      String.match?(value, ~r/\A[\w-]+(\.[\w-]+)+(\/\S*)?\z/)
  end

  defp normalize(changeset) do
    url = normalize_url(get_field(changeset, :url))
    receiver_id = normalize_receiver_id(get_field(changeset, :receiver_id))

    changeset
    |> put_change(:url, url)
    |> put_change(:receiver_id, receiver_id)
  end

  defp normalize_url(nil), do: nil

  defp normalize_url(value) do
    if url?(value) and not String.match?(value, ~r/\Ahttps?:\/\//) do
      "https://#{value}"
    else
      value
    end
  end

  defp normalize_receiver_id(nil), do: nil
  defp normalize_receiver_id(value), do: String.upcase(value)
end
