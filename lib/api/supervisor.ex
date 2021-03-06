defmodule Dexaggregatex.API.Supervisor do
  @moduledoc false
  use Supervisor

  alias Dexaggregatex.API.Endpoint

  @spec start_link(any) :: Supervisor.on_start()
  def start_link(init_args) do
    Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      Endpoint,
      {Absinthe.Subscription, [Endpoint]}
    ]

    # All children will be restarted if one crashes.
    Supervisor.init(children, strategy: :one_for_all)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @spec config_change(any, any, any) :: :ok
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end
end
