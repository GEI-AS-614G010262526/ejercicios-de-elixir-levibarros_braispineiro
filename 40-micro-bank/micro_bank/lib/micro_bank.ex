defmodule MicroBank do
  @moduledoc """
  MicroBank: un servidor bancario simple implementado con GenServer.
  """

  use GenServer

  # CLIENTE 

  @doc "Inicia el servidor bancario con una lista de cuentas opcional."
  def start_link(initial_accounts \\ %{}) do
    GenServer.start_link(__MODULE__, initial_accounts, name: __MODULE__)
  end

  @doc "Detiene el servidor."
  def stop() do
    GenServer.stop(__MODULE__)
  end

  @doc "Consulta el saldo de una cuenta."
  def ask(who) do
    GenServer.call(__MODULE__, {:ask, who})
  end

  @doc "Deposita una cantidad en la cuenta indicada."
  def deposit(who, amount) when is_atom(who) and is_number(amount) and amount > 0 do
    GenServer.call(__MODULE__, {:deposit, who, amount})
  end

  @doc "Retira una cantidad de una cuenta, si hay saldo suficiente."
  def withdraw(who, amount) when is_atom(who) and is_number(amount) and amount > 0 do
    GenServer.call(__MODULE__, {:withdraw, who, amount})
  end

  # SERVIDOR

  @impl true
  def init(initial_accounts) do
    {:ok, initial_accounts}
  end

  @impl true
  def handle_call({:ask, who}, _from, state) do
    case Map.get(state, who) do
      nil -> {:reply, {:error, :no_cuenta}, state}
      saldo -> {:reply, {:ok, saldo}, state}
    end
  end

  @impl true
  def handle_call({:deposit, who, amount}, _from, state) do
    nuevo_saldo = Map.get(state, who, 0) + amount
    {:reply, {:ok, nuevo_saldo}, Map.put(state, who, nuevo_saldo)}
  end

  @impl true
  def handle_call({:withdraw, who, amount}, _from, state) do
    case Map.get(state, who) do
      nil ->
        {:reply, {:error, :no_cuenta}, state}

      saldo when saldo < amount ->
        {:reply, {:error, :saldo_insuficiente}, state}

      saldo ->
        nuevo_saldo = saldo - amount
        {:reply, {:ok, nuevo_saldo}, Map.put(state, who, nuevo_saldo)}
    end
  end
end

