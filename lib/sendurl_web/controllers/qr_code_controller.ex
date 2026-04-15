defmodule SendurlWeb.QrCodeController do
  use SendurlWeb, :controller
  use SendurlWeb, :verified_routes

  def show(conn, %{"id" => id}) do
    send_url = url(conn, ~p"/send/#{id}")

    svg =
      send_url
      |> EQRCode.encode()
      |> EQRCode.svg()

    conn
    |> put_resp_content_type("image/svg+xml")
    |> text(svg)
  end
end
