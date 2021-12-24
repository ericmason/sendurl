defmodule IdGenerator do
  def assign_id(conn, _opts) do
    
    id = Plug.Conn.get_session(conn, :id) || random_id
    IO.puts "session id: #{id}"
    conn
    |> Plug.Conn.put_session(:id, id)
  end


  defp random_id do
    for _ <- 1..6, into: "", do: <<Enum.random('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ')>>
  end

end