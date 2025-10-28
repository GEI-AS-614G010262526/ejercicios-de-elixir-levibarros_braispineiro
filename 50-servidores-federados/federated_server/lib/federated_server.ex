defmodule FederatedServer do
  use GenServer
  @local_name :server_process

  # API PÚBLICA (para Clientes)


  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: @local_name)
  end

  def get_profile(requestor, actor_id) do
    GenServer.call(@local_name, {:get_profile, requestor, actor_id})
  end

  def post_message(sender, receiver, message) do
    GenServer.call(@local_name, {:post_message, sender, receiver, message})
  end

  def retrieve_messages(actor) do
    GenServer.call(@local_name, {:retrieve_messages, actor})
  end

  # Callbacks del GenServer

  @impl true
  def init(init_args) do
    {actor_list, server_name} =
      case init_args do
        list when is_list(list) ->
          {list, discover_server_name()}

        %{actors: list, name: name} ->
          {list, name}
      end

    local_actors =
      for actor_data <- actor_list, reduce: %{} do
        acc ->
          [user, _server] = String.split(actor_data.profile.id, "@")
          Map.put(acc, user, actor_data)
      end

    state = %{
      server_name: server_name,
      actors: local_actors
    }

    {:ok, state}
  end

  # Callbacks de Cliente

  @impl true
  def handle_call({:retrieve_messages, actor_id}, _from, state) do
    case get_local_actor(actor_id, state) do
      {:ok, actor_data} ->
        {:reply, {:ok, actor_data.inbox}, state}

      :not_found ->
        {:reply, {:error, :unauthorized_requestor}, state}
    end
  end

  @impl true
  def handle_call({:get_profile, requestor_id, target_actor_id}, _from, state) do
    unless actor_is_local?(requestor_id, state) do
      {:reply, {:error, :unauthorized_requestor}, state}
    else
      [_target_user, target_server_name] = parse_actor(target_actor_id)

      if target_server_name == state.server_name do
        do_local_profile_lookup(target_actor_id, state)
      else
        do_federated_profile_lookup(target_actor_id, state)
      end
    end
  end

  @impl true
  def handle_call({:post_message, sender_id, receiver_id, message}, _from, state) do
    unless actor_is_local?(sender_id, state) do
      {:reply, {:error, :unauthorized_requestor}, state}
    else
      [_receiver_user, receiver_server_name] = parse_actor(receiver_id)

      if receiver_server_name == state.server_name do
        do_local_message_delivery(sender_id, receiver_id, message, state)
      else
        do_federated_message_delivery(sender_id, receiver_id, message, state)
      end
    end
  end


  @impl true
  def handle_call({:s2s_get_profile, from_server, actor_id}, _from, state) do
    IO.puts(
      "#{state.server_name}: Petición S2S recibida de #{from_server} para ver #{actor_id}"
    )

    do_local_profile_lookup(actor_id, state)
  end

  @impl true
  def handle_call({:s2s_post_message, from_server, sender_id, receiver_id, message}, _from, state) do
    IO.puts(
      "#{state.server_name}: Petición S2S recibida de #{from_server} para entregar msg a #{receiver_id}"
    )

    do_local_message_delivery(sender_id, receiver_id, message, state)
  end



  defp do_local_profile_lookup(actor_id, state) do
    case get_local_actor(actor_id, state) do
      {:ok, actor_data} ->
        {:reply, {:ok, actor_data.profile}, state}

      :not_found ->
        {:reply, {:error, :actor_not_found}, state}
    end
  end

  defp do_local_message_delivery(sender_id, receiver_id, message, state) do
    [receiver_user, _] = parse_actor(receiver_id)

    case Map.get(state.actors, receiver_user) do
      nil ->
        {:reply, {:error, :actor_not_found}, state}

      actor_data ->
        new_message = %{
          from: sender_id,
          timestamp: DateTime.utc_now(),
          content: message
        }

        new_inbox = [new_message | actor_data.inbox]
        updated_actor = %{actor_data | inbox: new_inbox}
        new_actors = Map.put(state.actors, receiver_user, updated_actor)

        {:reply, :ok, %{state | actors: new_actors}}
    end
  end


  defp do_federated_profile_lookup(target_actor_id, state) do
    [_user, target_server] = parse_actor(target_actor_id)
    IO.puts(
      "#{state.server_name}: Federando petición de perfil para #{target_actor_id} a #{target_server}"
    )

    s2s_message = {:s2s_get_profile, state.server_name, target_actor_id}

    case federated_call(target_server, s2s_message) do
      {:ok, profile} -> {:reply, {:ok, profile}, state}
      error -> {:reply, error, state}
    end
  end

  defp do_federated_message_delivery(sender_id, receiver_id, message, state) do
    [_user, target_server] = parse_actor(receiver_id)
    IO.puts(
      "#{state.server_name}: Federando envío de mensaje para #{receiver_id} a #{target_server}"
    )


    s2s_message = {:s2s_post_message, state.server_name, sender_id, receiver_id, message}

    case federated_call(target_server, s2s_message) do
      :ok -> {:reply, :ok, state}
      error -> {:reply, error, state}
    end
  end

  # Helpers de Federación y Actores

  defp federated_call(target_server, message) do
    case find_remote_node_atom(target_server) do
      {:error, reason} ->
        reason

      {:ok, remote_node_atom} ->
        try do
          GenServer.call({@local_name, remote_node_atom}, message)
        rescue
          e in [RuntimeError, ArgumentError] ->
            IO.inspect(e, label: "Error en llamada federada")
            {:error, :node_not_available}
        catch
          :exit, _ -> {:error, :node_not_available}
        end
    end
  end

  defp find_remote_node_atom(server_name_string) do
    target_name = server_name_string

    case Node.list() |> Enum.find(&(&1 |> Atom.to_string() |> String.starts_with?("#{target_name}@"))) do
      nil -> {:error, :node_not_found_or_not_connected}
      node_atom -> {:ok, node_atom}
    end
  end

  defp get_local_actor(actor_id, state) do
    [user, server] = parse_actor(actor_id)

    if server == state.server_name do
      case Map.get(state.actors, user) do
        nil -> :not_found
        actor_data -> {:ok, actor_data}
      end
    else
      :not_found
    end
  end

  defp actor_is_local?(actor_id, state) do
    case get_local_actor(actor_id, state) do
      {:ok, _} -> true
      :not_found -> false
    end
  end

  defp parse_actor(actor_id) when is_binary(actor_id) do
    String.split(actor_id, "@")
  end

  defp discover_server_name() do
    Node.self()
    |> Atom.to_string()
    |> String.split("@")
    |> hd()
  end
end
