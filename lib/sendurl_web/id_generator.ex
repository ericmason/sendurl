defmodule IdGenerator do
  def assign_id(conn, _opts) do
    id = Plug.Conn.get_session(conn, :id) || random_id
    Plug.Conn.put_session(conn, :id, id)
  end


  defp random_id do
    for _ <- 1..6, into: "", do: <<Enum.random('23456789ABCDEFGHJKLMNPQRSTUVWXYZ')>>
  end

end