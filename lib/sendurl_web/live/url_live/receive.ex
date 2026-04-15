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
      |> assign(:text, nil)
      |> assign(:title, "Waiting to Receive a URL or Text")}
  end

  def handle_info(%{payload: url, event: "url"}, socket) do
    {:noreply,
      socket
      |> assign(:title, "Going to #{url}")
      |> redirect(external: url)
    }
  end

  def handle_info(%{payload: text, event: "text"}, socket) do
    {:noreply,
      socket
      |> assign(:title, "Received Text")
      |> assign(:text, text)
      |> assign(:url, nil)
    }
  end

  def handle_info(%{payload: value, event: "updated"}, socket) do
    {:noreply,
      socket
      |> assign(:url, value)
      |> assign(:text, nil)
    }
  end

  def handle_info(%{payload: value, event: "text_updated"}, socket) do
    {:noreply,
      socket
      |> assign(:text, value)
      |> assign(:url, nil)
    }
  end

end
