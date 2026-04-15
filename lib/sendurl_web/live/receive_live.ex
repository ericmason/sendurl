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
     |> assign(:file_count, 0)
     |> assign(:receiving?, false)
     |> assign(:title, "Waiting to Receive")}
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

  def handle_info(%{event: "rtc_signal", payload: signal}, socket) do
    {:noreply, push_event(socket, "rtc_signal", signal)}
  end

  @impl true
  def handle_event("rtc_signal", %{"signal" => signal}, socket) do
    SendurlWeb.Endpoint.broadcast_from(self(), "url:#{socket.assigns.id}", "rtc_signal", signal)
    {:noreply, socket}
  end

  def handle_event("file_started", _params, socket) do
    {:noreply, assign(socket, :receiving?, true)}
  end

  def handle_event("file_received", _params, socket) do
    {:noreply,
     socket
     |> assign(:file_count, socket.assigns.file_count + 1)
     |> assign(:receiving?, false)
     |> assign(:title, "Received File")}
  end

  def handle_event("clear", _params, socket) do
    {:noreply,
     socket
     |> assign(:url, nil)
     |> assign(:text, nil)
     |> assign(:file_count, 0)
     |> assign(:receiving?, false)
     |> assign(:title, "Waiting to Receive")
     |> push_event("clear_files", %{})}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:has_content?, has_content?(assigns))
      |> assign(:active?, has_content?(assigns) or assigns.receiving?)

    ~H"""
    <Layouts.app
      flash={@flash}
      max_width={if @active?, do: "max-w-none", else: "max-w-2xl"}
    >
      <div
        id="receive-file-area"
        phx-hook="WebRTCReceiver"
        phx-update="ignore"
        class="received-files space-y-4"
      >
        <div
          id="receive-progress"
          class="received-progress space-y-2 rounded border border-base-300 bg-base-100 p-3"
          hidden
        >
          <div class="flex items-center justify-between gap-3 flex-wrap">
            <span id="receive-progress-name" class="font-medium break-all">Receiving…</span>
            <span id="receive-progress-pct" class="text-sm opacity-80">0%</span>
          </div>
          <progress id="receive-progress-bar" value="0" max="100" class="progress w-full"></progress>
        </div>
        <div id="receive-file-status" class="sr-only" aria-live="polite"></div>
        <div id="receive-file-list" class="space-y-4"></div>
      </div>

      <div :if={@has_content?} class="space-y-4">
        <div :if={@url} class="text-lg break-all">URL incoming: {@url}</div>

        <div :if={@text} class="received-text space-y-2">
          <h3 class="text-xl font-semibold">Received Text</h3>
          <pre class="whitespace-pre-wrap break-words bg-base-200 p-3 rounded">{@text}</pre>
          <div class="flex gap-2">
            <button
              type="button"
              id="copy-text"
              class="btn btn-primary"
              phx-hook="Copy"
              data-text={@text}
            >
              Copy
            </button>
            <button type="button" class="btn" phx-click="clear">Clear</button>
          </div>
        </div>

        <div :if={@url && !@text && @file_count == 0}>
          <button type="button" class="btn" phx-click="clear">Clear</button>
        </div>
      </div>

      <div :if={not @active?} class="space-y-4">
        <h2 class="text-2xl font-semibold">{@title}</h2>

        <div class="qr-code">
          <img src={~p"/qr_code/#{@id}"} alt="QR Code" class="mx-auto" />
          <div class="text-sm break-all">{url(~p"/send/#{@id}")}</div>
        </div>

        <p class="text-2xl">My Receiver Code: <strong>{@id}</strong></p>

        <h3 class="text-xl font-semibold">How to Send Here</h3>
        <ol class="list-decimal ml-6 space-y-1">
          <li>
            Go to the <.link navigate={~p"/send"} class="link">Send</.link> page on another device.
          </li>
          <li>Enter the receiver code <strong>{@id}</strong></li>
          <li>Enter a URL or any text, or pick a file or picture to send</li>
          <li>Press Send (or Send File)</li>
          <li>
            If you sent a URL, this page will go there.
            Text shows a Copy button. Files and pictures appear above, full-size, with a Save button.
          </li>
        </ol>

        <p>
          <.link navigate={~p"/send"} class="link text-xl">
            Send a URL, Text, or File
          </.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp has_content?(assigns) do
    assigns.text not in [nil, ""] or
      assigns.url not in [nil, ""] or
      assigns.file_count > 0
  end
end
