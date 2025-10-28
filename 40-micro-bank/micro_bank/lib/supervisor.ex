defmodule MicroBank.Supervisor do
  @moduledoc """
  Supervisor del servidor MicroBank.
  Reinicia el servidor si este falla.
  """

  use Supervisor

  def start_link(init_arg \\ %{}) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(init_arg) do
    children = [
      # Reinicia el servidor MicroBank si se cae
      %{
        id: MicroBank,
        start: {MicroBank, :start_link, [init_arg]},
        restart: :permanent, # Reinicio garantizado
        shutdown: 5000,
        type: :worker
      }
    ]

    # Si el único hijo falla se reinicia.
    Supervisor.init(children, strategy: :one_for_one)
  end
end

