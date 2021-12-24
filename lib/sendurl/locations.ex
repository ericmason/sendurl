defmodule Sendurl.Locations do
  @moduledoc """
  The Locations context.
  """

  import Ecto.Query, warn: false
  alias Sendurl.Repo

  alias Sendurl.Locations.URL

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking url changes.

  ## Examples

      iex> change_url(url)
      %Ecto.Changeset{data: %URL{}}

  """
  def change_url(%URL{} = url, attrs \\ %{}) do
    URL.changeset(url, attrs)
  end
end
