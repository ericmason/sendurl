defmodule Sendurl.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      # Sendurl.Repo,
      # Start the Telemetry supervisor
      SendurlWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Sendurl.PubSub},
      # Start the Endpoint (http/https)
      SendurlWeb.Endpoint
      # Start a worker by calling: Sendurl.Worker.start_link(arg)
      # {Sendurl.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sendurl.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SendurlWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
