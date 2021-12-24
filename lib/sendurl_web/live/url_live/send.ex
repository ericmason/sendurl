defmodule SendurlWeb.URLLive.Send do
  use SendurlWeb, :live_view

  alias Sendurl.Locations

  @impl true
  def mount(_params, session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_, _, socket) do
    {:noreply,
     socket
     |> assign(:changeset, Locations.change_url(%Locations.URL{}))
     |> assign(:url, %Locations.URL{})}
  end

  @impl true
  def handle_event("validate", %{"url" => url_params}, socket) do
    changeset =
      socket.assigns.url
      |> Locations.change_url(url_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("send", %{"url" => url_params}, socket) do
    changeset =
      socket.assigns.url
      |> Locations.change_url(Map.put(url_params, "url", ""))

    IO.inspect(changeset)
    
    url = Map.get(url_params, "url")
    receiver_id = Map.get(url_params, "receiver_id")
    SendurlWeb.Endpoint.broadcast_from(self(), "url:#{receiver_id}", "url", url)

    {:noreply,
      socket
      |> assign(changeset: changeset)
      |> put_flash(:info, "#{url_params["url"]} sent to #{url_params["receiver_id"]}!")}
  end

end
