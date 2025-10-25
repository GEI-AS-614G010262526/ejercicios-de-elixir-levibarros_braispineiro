defmodule GestorDistribuido do
  use GenServer


  #Inicia el servidor GenServer y lo registra globalmente con el nombre :gestor
  def start_link(recursos_iniciales) do
    #Usamos :global para registrar el nombre en todos los nodos
    GenServer.start_link(__MODULE__, recursos_iniciales, name: {:global, :gestor})
  end


  #Solicita la asignación de un recurso desde cualquier nodo
  def alloc() do
    # Especificamos que el nombre :gestor es global
    GenServer.call({:global, :gestor}, {:alloc, self()})
  end


  #Libera un recurso previamente asignado desde cualquier nodo
  def release(recurso) do
    GenServer.call({:global, :gestor}, {:release, self(), recurso})
  end


  #Devuelve el número de recursos disponibles desde cualquier nodo
  def avail() do
    GenServer.call({:global, :gestor}, {:avail, self()})
  end

  #Lógica del Server (Callbacks de GenServer)

  @impl true
  def init(recursos_iniciales) do
    estado = %{
      disponibles: recursos_iniciales,
      asignados: %{}
    }
    {:ok, estado}
  end

  @impl true
  def handle_call({:alloc, from}, _from_ref, estado) do
    case estado.disponibles do
      [] ->
        {:reply, {:error, :sin_recursos}, estado}
      [recurso | resto_disponibles] ->
        nuevo_estado = %{
          disponibles: resto_disponibles,
          asignados: Map.put(estado.asignados, recurso, from)
        }
        {:reply, {:ok, recurso}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:release, from, recurso}, _from_ref, estado) do
    case Map.get(estado.asignados, recurso) do
      ^from ->
        nuevo_estado = %{
          disponibles: [recurso | estado.disponibles],
          asignados: Map.delete(estado.asignados, recurso)
        }
        {:reply, :ok, nuevo_estado}
      _ ->
        {:reply, {:error, :recurso_no_reservado}, estado}
    end
  end

  @impl true
  def handle_call({:avail, _from}, _from_ref, estado) do
    num_disponibles = Enum.count(estado.disponibles)
    {:reply, num_disponibles, estado}
  end
end
