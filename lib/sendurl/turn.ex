defmodule Sendurl.Turn do
  @moduledoc """
  Mints and caches Cloudflare Realtime TURN ICE server credentials.

  Cloudflare generates short-lived TURN credentials via:
  POST https://rtc.live.cloudflare.com/v1/turn/keys/{KEY_ID}/credentials/generate-ice-servers

  We cache one set of credentials process-wide and refresh them a few
  minutes before they expire. If the Cloudflare call fails we fall back
  to STUN-only, which still works for same-LAN transfers.
  """
  use GenServer

  require Logger

  @refresh_buffer_seconds 600
  @default_ttl_seconds 86_400
  @fallback_ice_servers [%{urls: "stun:stun.cloudflare.com:3478"}]

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @spec ice_servers() :: [map()]
  def ice_servers do
    GenServer.call(__MODULE__, :ice_servers, 5_000)
  catch
    :exit, _ -> @fallback_ice_servers
  end

  @impl true
  def init(_state) do
    {:ok, %{servers: nil, expires_at: 0}}
  end

  @impl true
  def handle_call(:ice_servers, _from, state) do
    state = ensure_fresh(state)
    {:reply, state.servers || @fallback_ice_servers, state}
  end

  defp ensure_fresh(state) do
    now = System.system_time(:second)

    if is_nil(state.servers) or now + @refresh_buffer_seconds >= state.expires_at do
      case fetch() do
        {:ok, servers} ->
          %{servers: servers, expires_at: now + @default_ttl_seconds}

        {:error, reason} ->
          Logger.warning("TURN credentials fetch failed: #{inspect(reason)}")
          state
      end
    else
      state
    end
  end

  defp fetch do
    config = Application.get_env(:sendurl, __MODULE__, [])
    key_id = config[:key_id]
    api_token = config[:api_token]

    if is_binary(key_id) and is_binary(api_token) do
      url =
        "https://rtc.live.cloudflare.com/v1/turn/keys/#{key_id}/credentials/generate-ice-servers"

      case Req.post(url,
             auth: {:bearer, api_token},
             json: %{ttl: @default_ttl_seconds},
             receive_timeout: 4_000
           ) do
        {:ok, %Req.Response{status: status, body: %{"iceServers" => servers}}}
        when status in 200..299 and is_list(servers) ->
          {:ok, servers}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, {status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :missing_credentials}
    end
  end
end
