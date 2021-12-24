defmodule Sendurl.Repo do
  use Ecto.Repo,
    otp_app: :sendurl,
    adapter: Ecto.Adapters.Postgres
end
