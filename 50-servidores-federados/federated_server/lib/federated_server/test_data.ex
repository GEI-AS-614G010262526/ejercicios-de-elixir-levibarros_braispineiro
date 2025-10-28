defmodule FederatedServer.TestData do


  def enterprise_actors do
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

  def cimitar_actors do
    [
      %{
        profile: %{
          id: "pretor@cimitar",
          name: "Shinzon",
          avatar: "http://example.com/pretor.png"
        },
        inbox: []
      },
      %{
        profile: %{
          id: "virrey@cimitar",
          name: "Viceroy",
          avatar: "http://example.com/virrey.png"
        },
        inbox: []
      }
    ]
  end
end
