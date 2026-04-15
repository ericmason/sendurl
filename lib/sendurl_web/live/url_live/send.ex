defmodule SendurlWeb.URLLive.Send do
  use SendurlWeb, :live_view

  alias Sendurl.Locations
  import Ecto.Changeset

  @impl true
  def mount(_params, session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _, socket) do
    changeset = Locations.change_url(%Locations.URL{}, %{receiver_id: params["id"]})

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:url, %Locations.URL{})}
  end

  @impl true
  def handle_event("validate", %{"url" => url_params}, socket) do
    changeset =
      socket.assigns.url
      |> Locations.change_url(url_params)
      |> Map.put(:action, :validate)

    receiver_id = get_field(changeset, :receiver_id)
    value = get_field(changeset, :url)
    event = if Locations.URL.url?(value), do: "updated", else: "text_updated"
    SendurlWeb.Endpoint.broadcast_from(self(), "url:#{receiver_id}", event, value)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("send", %{"url" => url_params}, socket) do
    changeset =
      socket.assigns.url
      |> Locations.change_url(url_params)

    value = get_field(changeset, :url)
    receiver_id = get_field(changeset, :receiver_id)

    {event, kind} =
      if Locations.URL.url?(value), do: {"url", "URL"}, else: {"text", "Text"}

    SendurlWeb.Endpoint.broadcast_from(self(), "url:#{receiver_id}", event, value)

    {:noreply,
      socket
      |> assign(changeset: changeset)
      |> put_flash(:info, "#{kind} sent to #{receiver_id}!")}
  end

end
