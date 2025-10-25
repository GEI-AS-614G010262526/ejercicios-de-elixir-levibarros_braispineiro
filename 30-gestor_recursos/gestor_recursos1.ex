defmodule Gestor do
  use GenServer



  #Inicia el servidor GenServer y lo registra localmente con el nombre :gestor
  def start_link(recursos_iniciales) do
    GenServer.start_link(__MODULE__, recursos_iniciales, name: :gestor)
  end


  #Solicita la asignación de un recurso
  def alloc() do
    GenServer.call(:gestor, {:alloc, self()})
  end


  #Libera un recurso previamente asignado
  def release(recurso) do
    GenServer.call(:gestor, {:release, self(), recurso})
  end

  #Devuelve el número de recursos disponibles
  def avail() do
    GenServer.call(:gestor, {:avail, self()})
  end

  #Lógica del Server (Callbacks de GenServer

  @impl true
  def init(recursos_iniciales) do
    #El estado se representa con un mapa que contiene los recursos
    #disponibles y un mapa de los recursos asignados (recurso => pid)
    estado = %{
      disponibles: recursos_iniciales,
      asignados: %{}
    }
    {:ok, estado}
  end

  @impl true
  def handle_call({:alloc, from}, _from_ref, estado) do
    case estado.disponibles do
      #Si no hay recursos, devuelve error
      [] ->
        {:reply, {:error, :sin_recursos}, estado}

      #Si hay recursos, asigna el primero de la lista
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
    #Comprueba si el recurso fue asignado al proceso que intenta liberarlo
    case Map.get(estado.asignados, recurso) do
      #El pin operator `^` asegura que el valor de `from` coincide
      ^from ->
        nuevo_estado = %{
          disponibles: [recurso | estado.disponibles],
          asignados: Map.delete(estado.asignados, recurso)
        }
        {:reply, :ok, nuevo_estado}

      #Si no devuelve un error
      _ ->
        {:reply, {:error, :recurso_no_reservado}, estado}
    end
  end

  @impl true
  def handle_call({:avail, _from}, _from_ref, estado) do
    #Devuelve la cantidad de elementos en la lista de disponibles
    num_disponibles = Enum.count(estado.disponibles)
    {:reply, num_disponibles, estado}
  end
end





defmodule Gestor.Pruebas do

  def pruebas() do
    IO.puts("--- INICIANDO PRUEBAS DEL GESTOR DE RECURSOS ---")
    #Inicia el gestor con 4 recursos
    {:ok, _pid} = Gestor.start_link([:a, :b, :c, :d])

    IO.puts("\n>>> Prueba 1: Ciclo básico de asignación y liberación")
    IO.inspect(Gestor.avail())
    #Esperado: 4

    {:ok, mi_recurso} = Gestor.alloc()
    IO.inspect({:ok, mi_recurso})
    #Esperado: {:ok, :a}

    IO.inspect(Gestor.avail())
    #Esperado: 3

    IO.inspect(Gestor.release(mi_recurso))
    #Esperado: :ok

    IO.inspect(Gestor.avail())
    #Esperado: 4

    IO.puts("\n>>> Prueba 2: Errores comunes")
    IO.puts("--- Intentando liberar recurso de otro proceso...")
    {:ok, recurso_ajeno} = Gestor.alloc()
    #Creamos otro proceso que intenta liberar un recurso que no le pertenece
    spawn(fn -> IO.inspect(Gestor.release(recurso_ajeno)) end)
    Process.sleep(100) # Pequeña pausa para ver el resultado del otro proceso
    #Esperado (la línea de abajo aparecerá de forma asíncrona):
    #{:error, :recurso_no_reservado}
    Gestor.release(recurso_ajeno) # Liberamos correctamente para limpiar

    IO.puts("\n--- Intentando liberar recurso inexistente...")
    IO.inspect(Gestor.release(:recurso_inexistente))
    #Esperado: {:error, :recurso_no_reservado}

    IO.puts("\n>>> Prueba 3: Agotar los recursos")
    Gestor.alloc()
    Gestor.alloc()
    Gestor.alloc()
    IO.inspect(Gestor.avail())
    #Esperado: 0

    IO.inspect(Gestor.alloc())
    #Esperado: {:error, :sin_recursos}

    IO.puts("\n--- PRUEBAS FINALIZADAS ---")
  end
end
