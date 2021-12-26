defmodule SendurlWeb.URLLive.Receive do
  use SendurlWeb, :live_view

  alias Sendurl.Locations

  @impl true
  def mount(_params, session, socket) do
    
    id = Map.get(session, "id")
    SendurlWeb.Endpoint.subscribe("url:#{id}")
    {:ok, 
      socket 
      |> assign(:id, id)
      |> assign(:url, nil)
      |> assign(:title, "Waiting to Receive a URL")}
  end

  def handle_info(%{topic: topic, payload: url, event: "url"}, socket) do
    IO.puts("Received broadcast for #{url}")
    
    {:noreply, 
      socket 
      |> assign(:title, "Going to #{url}")
      |> redirect(external: url)
    }
  end

  def handle_info(%{topic: topic, payload: url, event: "updated"}, socket) do
    IO.puts("Received update broadcast for #{url}")
    
    {:noreply, 
      socket 
      |> assign(:url, url)
    }
  end

end
