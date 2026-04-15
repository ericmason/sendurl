defmodule SendurlWeb.SendLive do
  use SendurlWeb, :live_view

  alias Sendurl.URL

  @receiver_id_regex ~r/\A[A-Z0-9]{6}\z/

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:url, %URL{})
     |> assign(:subscribed_topic, nil)
     |> assign(:ice_servers_json, Jason.encode!(Sendurl.Turn.ice_servers()))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    changeset = URL.changeset(socket.assigns.url, %{receiver_id: params["id"]})
    receiver_id = Ecto.Changeset.get_field(changeset, :receiver_id)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:receiver_id, receiver_id)
     |> maybe_subscribe(receiver_id)}
  end

  @impl true
  def handle_event("validate", %{"url" => params}, socket) do
    changeset =
      socket.assigns.url
      |> URL.changeset(params)
      |> Map.put(:action, :validate)

    receiver_id = Ecto.Changeset.get_field(changeset, :receiver_id)
    value = Ecto.Changeset.get_field(changeset, :url)
    event = if URL.url?(value), do: "updated", else: "text_updated"
    SendurlWeb.Endpoint.broadcast_from(self(), "url:#{receiver_id}", event, value)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> maybe_subscribe(receiver_id)}
  end

  def handle_event("send", %{"url" => params}, socket) do
    changeset = URL.changeset(socket.assigns.url, params)
    value = Ecto.Changeset.get_field(changeset, :url)
    receiver_id = Ecto.Changeset.get_field(changeset, :receiver_id)

    {event, kind} =
      if URL.url?(value), do: {"url", "URL"}, else: {"text", "Text"}

    SendurlWeb.Endpoint.broadcast_from(self(), "url:#{receiver_id}", event, value)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> put_flash(:info, "#{kind} sent to #{receiver_id}!")}
  end

  def handle_event("rtc_signal", %{"receiver_id" => receiver_id, "signal" => signal}, socket) do
    case normalize_id(receiver_id) do
      nil ->
        {:noreply, socket}

      valid_id ->
        socket = maybe_subscribe(socket, valid_id)
        SendurlWeb.Endpoint.broadcast_from(self(), "url:#{valid_id}", "rtc_signal", signal)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{event: "rtc_signal", payload: signal}, socket) do
    {:noreply, push_event(socket, "rtc_signal", signal)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp maybe_subscribe(socket, receiver_id) do
    if connected?(socket) do
      current = socket.assigns[:subscribed_topic]
      new_topic = topic_for(receiver_id)

      cond do
        current == new_topic ->
          socket

        true ->
          if current, do: SendurlWeb.Endpoint.unsubscribe(current)
          if new_topic, do: SendurlWeb.Endpoint.subscribe(new_topic)
          assign(socket, :subscribed_topic, new_topic)
      end
    else
      socket
    end
  end

  defp topic_for(id) do
    case normalize_id(id) do
      nil -> nil
      valid -> "url:#{valid}"
    end
  end

  defp normalize_id(id) when is_binary(id) do
    upper = String.upcase(id)
    if String.match?(upper, @receiver_id_regex), do: upper, else: nil
  end

  defp normalize_id(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.form
        for={@form}
        phx-change="validate"
        phx-submit="send"
        class="space-y-6"
      >
        <div>
          <label for="url_receiver_id" class="block font-semibold">
            Receiver ID (who to send to)
          </label>
          <div class="input-with-clear">
            <input
              type="text"
              name="url[receiver_id]"
              id="url_receiver_id"
              value={Phoenix.HTML.Form.input_value(@form, :receiver_id)}
              class="input input-bordered input-receiver-id"
              phx-hook="RememberInput"
              data-remember-key="sendurl:receiver_id"
              data-remember-max-age="3600000"
              data-upcase="true"
              autocomplete="off"
            />
            <button
              type="button"
              id="clear-receiver-id"
              class="clear-button"
              aria-label="Clear receiver ID"
              phx-hook="ClearInput"
              data-target="url_receiver_id"
              data-clear-key="sendurl:receiver_id"
            >
              &times;
            </button>
          </div>
          <p
            :for={{msg, opts} <- @form[:receiver_id].errors}
            :if={used_input?(@form[:receiver_id])}
            class="text-error text-sm mt-1"
          >
            {translate_error({msg, opts})}
          </p>
        </div>

        <section class="space-y-3 pt-4 border-t border-base-200">
          <h2 class="text-2xl font-semibold">Send a URL or Text</h2>
          <div>
            <label for="url_url" class="block font-semibold">URL or Text</label>
            <input
              type="text"
              name="url[url]"
              id="url_url"
              value={Phoenix.HTML.Form.input_value(@form, :url)}
              class="input input-bordered w-full"
            />
            <p
              :for={{msg, opts} <- @form[:url].errors}
              :if={used_input?(@form[:url])}
              class="text-error text-sm mt-1"
            >
              {translate_error({msg, opts})}
            </p>
          </div>

          <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
            Send
          </button>
        </section>
      </.form>

      <section id="send-file-section" class="space-y-3 pt-4 border-t border-base-200">
        <h2 class="text-2xl font-semibold">Send a File or Picture</h2>
        <p class="text-sm opacity-70">
          Files and pictures transfer directly peer-to-peer with WebRTC. Keep the receiver page open on the other device until the transfer completes.
        </p>

        <div>
          <label for="send-file-input" class="block font-semibold">Choose a file</label>
          <input
            type="file"
            id="send-file-input"
            class="file-input file-input-bordered w-full"
            multiple
          />
        </div>

        <div class="flex items-center gap-3 flex-wrap">
          <button
            type="button"
            id="send-file-button"
            class="btn btn-primary"
            phx-hook="WebRTCSender"
            data-receiver-input="url_receiver_id"
            data-file-input="send-file-input"
            data-status="send-file-status"
            data-progress="send-file-progress"
            data-ice-servers={@ice_servers_json}
          >
            Send File
          </button>
          <span id="send-file-status" class="text-sm opacity-80" aria-live="polite"></span>
        </div>

        <progress
          id="send-file-progress"
          value="0"
          max="100"
          class="progress w-full hidden"
        >
        </progress>
      </section>
    </Layouts.app>
    """
  end
end
