defmodule FederatedServerTest do
  use ExUnit.Case, async: false

  alias FederatedServer

  defp test_actors do
    [
      %{
        profile: %{
          id: "picard@enterprise",
          name: "Jean-Luc Picard",
          avatar: "http://example.com/picard.png"
        },
        inbox: []
      },
      %{
        profile: %{
          id: "troi@enterprise",
          name: "Deanna Troi",
          avatar: "http://example.com/troi.png"
        },
        inbox: []
      }
    ]
  end

  setup do
    init_data = %{
      actors: test_actors(),
      name: "enterprise"
    }

    {:ok, pid} = FederatedServer.start_link(init_data)

    on_exit(fn ->
      Process.exit(pid, :shutdown)
    end)

    :ok
  end

  test "Obtener el perfil de un actor local" do
    assert {:ok, profile} =
             FederatedServer.get_profile("picard@enterprise", "picard@enterprise")

    assert profile.id == "picard@enterprise"
    assert profile.name == "Jean-Luc Picard"
    assert profile.avatar == "http://example.com/picard.png"
  end

  test "Recuperar perfil de otro usuario en el mismo servidor" do
    assert {:ok, profile} = FederatedServer.get_profile("picard@enterprise", "troi@enterprise")

    assert profile.id == "troi@enterprise"
    assert profile.name == "Deanna Troi"
  end

  test "Enviar un mensaje a un usuario local" do
    assert :ok ==
             FederatedServer.post_message(
               "picard@enterprise",
               "troi@enterprise",
               "Number One, my ready room."
             )

    assert {:ok, inbox} = FederatedServer.retrieve_messages("troi@enterprise")
    assert length(inbox) == 1

    [message] = inbox
    assert message.from == "picard@enterprise"
    assert message.content == "Number One, my ready room."
    assert message.timestamp
  end

  test "Error si un actor no local (no registrado) intenta realizar una acción" do
    assert {:error, :unauthorized_requestor} ==
             FederatedServer.get_profile("pretor@cimitar", "picard@enterprise")

    assert {:error, :unauthorized_requestor} ==
             FederatedServer.post_message(
               "pretor@cimitar",
               "picard@enterprise",
               "We are waiting."
             )
  end

  test "Error al recuperar mensajes si el actor no es local" do
    assert {:error, :unauthorized_requestor} ==
             FederatedServer.retrieve_messages("pretor@cimitar")
  end

  test "Recuperar una bandeja de entrada vacía" do
    assert {:ok, []} = FederatedServer.retrieve_messages("picard@enterprise")
  end
end
