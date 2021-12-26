defmodule SendurlWeb.QrCodeController do
  use SendurlWeb, :controller

  def show(conn, %{"id" => id}) do
    conn
    |> put_resp_content_type("image/svg+xml")
    |> text(make_svg(conn, id))
  end

  defp make_svg(conn, id) do
    SendurlWeb.Router.Helpers.url_send_url(conn, :send, id)
    |> EQRCode.encode()
    |> EQRCode.svg()
  end
end