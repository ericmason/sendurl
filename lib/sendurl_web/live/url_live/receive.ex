defmodule SendurlWeb.URLLive.Receive do
  use SendurlWeb, :live_view

  alias Sendurl.Locations

  @impl true
  def mount(_params, session, socket) do
    id = Map.get(session, "id")
    {:ok, assign(socket, :id, id)}
  end

end
