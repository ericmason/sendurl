defmodule SendurlWeb.URLLive.Receive do
  use SendurlWeb, :live_view

  alias Sendurl.Locations

  @impl true
  def mount(_params, session, socket) do
    
    id = Map.get(session, "id")
    SendurlWeb.Endpoint.subscribe("url:#{id}")
    {:ok, assign(socket, :id, id)}
  end

  def handle_info(%{topic: topic, payload: url}, socket) do
    IO.puts("Received broadcast for #{url}")
    
    {:noreply, redirect(socket, external: url)}
  end

end
