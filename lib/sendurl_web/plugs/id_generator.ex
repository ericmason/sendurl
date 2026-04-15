defmodule SendurlWeb.Plugs.IdGenerator do
  @moduledoc false
  @alphabet ~c"23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

  def init(opts), do: opts

  def call(conn, _opts) do
    id = Plug.Conn.get_session(conn, :id) || random_id()
    Plug.Conn.put_session(conn, :id, id)
  end

  defp random_id do
    for _ <- 1..6, into: "", do: <<Enum.random(@alphabet)>>
  end
end
