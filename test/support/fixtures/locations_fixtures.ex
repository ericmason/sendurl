defmodule Sendurl.LocationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Sendurl.Locations` context.
  """

  @doc """
  Generate a url.
  """
  def url_fixture(attrs \\ %{}) do
    {:ok, url} =
      attrs
      |> Enum.into(%{
        url: "some url"
      })
      |> Sendurl.Locations.create_url()

    url
  end
end
