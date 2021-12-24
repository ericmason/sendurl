defmodule SendurlWeb.URLLive.Index do
  use SendurlWeb, :live_view

  alias Sendurl.Locations
  alias Sendurl.Locations.URL

  @impl true
  def mount(_params, session, socket) do
    id = Map.get(session, "id")
    {:ok, assign(socket, :id, id)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :receive, _params) do
    socket
    |> assign(:page_title, "Receive URLs")
  end

  defp apply_action(socket, :send, _params) do
    socket

    |> assign(:page_title, "Receive URLs")
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Url")
    |> assign(:url, %URL{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Urls")
    |> assign(:url, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    url = Locations.get_url!(id)
    {:ok, _} = Locations.delete_url(url)

    {:noreply, assign(socket, :urls, list_urls())}
  end

  defp list_urls do
    Locations.list_urls()
  end
end
