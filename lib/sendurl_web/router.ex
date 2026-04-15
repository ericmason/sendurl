defmodule SendurlWeb.Router do
  use SendurlWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SendurlWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug SendurlWeb.Plugs.IdGenerator
  end

  scope "/", SendurlWeb do
    pipe_through :browser

    live "/", ReceiveLive
    live "/send", SendLive
    live "/send/:id", SendLive
    get "/qr_code/:id", QrCodeController, :show
  end
end
