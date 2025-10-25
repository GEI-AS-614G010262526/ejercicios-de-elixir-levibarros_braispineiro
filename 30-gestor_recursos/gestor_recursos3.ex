defmodule GestorTolerante do
  use GenServer


  def start_link(recursos_iniciales) do
    #Usamos :global para registrar el nombre en todos los nodos
    GenServer.start_link(__MODULE__, recursos_iniciales, name: {:global, :gestor})
  end

  def alloc() do
    GenServer.call({:global, :gestor}, {:alloc, self()})
  end

  def release(recurso) do
    GenServer.call({:global, :gestor}, {:release, self(), recurso})
  end

  def avail() do
    GenServer.call({:global, :gestor}, {:avail, self()})
  end

  #Callbacks de GenServer (Lógica del Server)

  @impl true
  def init(recursos_iniciales) do
    estado = %{
      disponibles: recursos_iniciales,
      #'asignados' ahora guarda: %{recurso => {pid_dueño, ref_monitor}}
      asignados: %{},
      #'ref_a_recurso' nos permite buscar al revés: %{ref_monitor => recurso}
      ref_a_recurso: %{}
    }
    {:ok, estado}
  end

  @impl true
  def handle_call({:alloc, from}, _from_ref, estado) do
    case estado.disponibles do
      [] ->
        {:reply, {:error, :sin_recursos}, estado}

      [recurso | resto_disponibles] ->
        #Creamos un monitor para el proceso cliente
        #'Process.monitor' devuelve una referencia
        ref = Process.monitor(from)

        #Guardamos el PID y la referencia
        nuevos_asignados = Map.put(estado.asignados, recurso, {from, ref})
        #Guardamos la búsqueda inversa ref -> recurso
        nuevos_refs = Map.put(estado.ref_a_recurso, ref, recurso)

        nuevo_estado = %{
          disponibles: resto_disponibles,
          asignados: nuevos_asignados,
          ref_a_recurso: nuevos_refs
        }
        {:reply, {:ok, recurso}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:release, from, recurso}, _from_ref, estado) do
    #Buscamos el recurso en el mapa de asignados
    case Map.get(estado.asignados, recurso) do
      #Comprobamos que el PID coincide (^from)
      #y extraemos la 'ref' del monitor
      {^from, ref} ->
        #Ya no necesitamos monitorizar, el recurso se devolvió bien
        #:flush elimina cualquier mensaje :DOWN que ya esté en la cola
        Process.demonitor(ref, [:flush])

        #Limpiamos ambos mapas
        nuevos_asignados = Map.delete(estado.asignados, recurso)
        nuevos_refs = Map.delete(estado.ref_a_recurso, ref)

        nuevo_estado = %{
          disponibles: [recurso | estado.disponibles],
          asignados: nuevos_asignados,
          ref_a_recurso: nuevos_refs
        }
        {:reply, :ok, nuevo_estado}

      _ ->
        #El recurso no existe o no pertenece al proceso 'from'
        {:reply, {:error, :recurso_no_reservado}, estado}
    end
  end

  @impl true
  def handle_call({:avail, _from}, _from_ref, estado) do
    num_disponibles = Enum.count(estado.disponibles)
    {:reply, num_disponibles, estado}
  end

  #Callback para manejar mensajes :DOWN

  @impl true
  #Este callback se dispara cuando un proceso que monitorizamos muere
  def handle_info({:DOWN, ref, :process, pid, _reason}, estado) do
    IO.puts("Gestor: ¡Caída detectada! Proceso #{inspect(pid)} ha muerto.")

    # Buscamos qué recurso estaba asociado a esa referencia de monitor
    case Map.pop(estado.ref_a_recurso, ref) do
      #Encontramos el recurso
      {recurso, nuevos_refs} ->
        IO.puts("Gestor: Recuperando recurso #{inspect(recurso)}.")
        #Lo quitamos también del mapa de asignados
        nuevos_asignados = Map.delete(estado.asignados, recurso)

        nuevo_estado = %{
          disponibles: [recurso | estado.disponibles],
          asignados: nuevos_asignados,
          ref_a_recurso: nuevos_refs
        }
        {:noreply, nuevo_estado}

      #No encontramos un recurso
      #Esto puede pasar si el proceso liberó el recurso (:release)
      #y murió justo después (el 'demonitor' y el ':DOWN' se cruzaron)
      #Es seguro ignorarlo
      nil ->
        IO.puts("Gestor: Mensaje :DOWN recibido para un monitor ya eliminado. Ignorando.")
        {:noreply, estado}
    end
  end

  #Callback genérico para cualquier otro mensaje
  @impl true
  def handle_info(_msg, estado) do
    {:noreply, estado}
  end
end
