defmodule SendurlWeb.ReceiveLive do
  use SendurlWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    id = Map.get(session, "id")

    if connected?(socket) do
      SendurlWeb.Endpoint.subscribe("url:#{id}")
    end

    {:ok,
     socket
     |> assign(:id, id)
     |> assign(:url, nil)
     |> assign(:text, nil)
     |> assign(:title, "Waiting to Receive a URL or Text")}
  end

  @impl true
  def handle_info(%{payload: url, event: "url"}, socket) do
    {:noreply,
     socket
     |> assign(:title, "Going to #{url}")
     |> redirect(external: url)}
  end

  def handle_info(%{payload: text, event: "text"}, socket) do
    {:noreply,
     socket
     |> assign(:title, "Received Text")
     |> assign(:text, text)
     |> assign(:url, nil)}
  end

  def handle_info(%{payload: value, event: "updated"}, socket) do
    {:noreply,
     socket
     |> assign(:url, value)
     |> assign(:text, nil)}
  end

  def handle_info(%{payload: value, event: "text_updated"}, socket) do
    {:noreply,
     socket
     |> assign(:text, value)
     |> assign(:url, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h2 class="text-2xl font-semibold">{@title}</h2>

      <div class="qr-code">
        <img src={~p"/qr_code/#{@id}"} alt="QR Code" class="mx-auto" />
        <div class="text-sm break-all">{url(~p"/send/#{@id}")}</div>
      </div>

      <div class="space-y-4">
        <p :if={@url} class="text-lg">URL incoming: {@url}</p>

        <div :if={@text} class="received-text space-y-2">
          <h3 class="text-xl font-semibold">Received Text</h3>
          <pre class="whitespace-pre-wrap break-words bg-base-200 p-3 rounded">{@text}</pre>
          <button
            type="button"
            id="copy-text"
            class="btn btn-primary"
            phx-hook="Copy"
            data-text={@text}
          >
            Copy
          </button>
        </div>

        <p class="text-2xl">My Receiver Code: <strong>{@id}</strong></p>

        <h3 class="text-xl font-semibold">How to Send a URL or Text Here</h3>
        <ol class="list-decimal ml-6 space-y-1">
          <li>
            Go to the <.link navigate={~p"/send"} class="link">Send</.link>
            page on another device.
          </li>
          <li>Enter the receiver code <strong>{@id}</strong></li>
          <li>Enter a URL or any text</li>
          <li>Press Send</li>
          <li>
            If you sent a URL, this page will go there.
            Otherwise the text appears with a Copy button.
          </li>
        </ol>

        <p>
          <.link navigate={~p"/send"} class="link text-xl">Send a URL or Text</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end
end
