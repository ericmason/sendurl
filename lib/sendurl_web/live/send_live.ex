defmodule SendurlWeb.SendLive do
  use SendurlWeb, :live_view

  alias Sendurl.URL

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :url, %URL{})}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    changeset = URL.changeset(socket.assigns.url, %{receiver_id: params["id"]})

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:receiver_id, Ecto.Changeset.get_field(changeset, :receiver_id))}
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

    {:noreply, assign(socket, :form, to_form(changeset))}
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h2 class="text-2xl font-semibold">Send a URL or Text</h2>

      <.form
        for={@form}
        phx-change="validate"
        phx-submit="send"
        class="space-y-4"
      >
        <div>
          <label for="url_receiver_id" class="block font-semibold">Receiver ID</label>
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
          <p :for={{msg, opts} <- @form[:receiver_id].errors} class="text-error text-sm mt-1">
            {translate_error({msg, opts})}
          </p>
        </div>

        <div>
          <label for="url_url" class="block font-semibold">URL or Text</label>
          <input
            type="text"
            name="url[url]"
            id="url_url"
            value={Phoenix.HTML.Form.input_value(@form, :url)}
            class="input input-bordered w-full"
          />
          <p :for={{msg, opts} <- @form[:url].errors} class="text-error text-sm mt-1">
            {translate_error({msg, opts})}
          </p>
        </div>

        <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
          Send
        </button>
      </.form>
    </Layouts.app>
    """
  end
end
