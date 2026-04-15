defmodule Sendurl.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SendurlWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:sendurl, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Sendurl.PubSub},
      # Start a worker by calling: Sendurl.Worker.start_link(arg)
      # {Sendurl.Worker, arg},
      # Start to serve requests, typically the last entry
      SendurlWeb.Endpoint
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
