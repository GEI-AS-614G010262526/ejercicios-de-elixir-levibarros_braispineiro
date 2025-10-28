defmodule Eratostenes do

  defp range(n) when n >= 2 do
    range(2, n)
  end

  defp range(current, max) when current <= max do
    [current | range(current + 1, max)]
  end

  defp range(_current, _max) do
    []
  end

  #Filtro: recibe un número primo y un siguiente proceso
  defp loop(:filtro, primo, next) do
    receive do
      #Mensaje para devolver la lista de primos
      {:return, pid} ->
        send(next, {:return, pid})

      #Si el número no es divisible por este primo, se envía al siguiente filtro
      num when rem(num, primo) != 0 ->
        send(next, num)
        loop(:filtro, primo, next)

      #Si es divisible, simplemente se ignora y seguimos recibiendo
      _num ->
        loop(:filtro, primo, next)
    end
  end


  #Cola inicial: primer proceso de la cadena de filtros
  defp loop(:cola, list) do
    receive do
      #Mensaje para devolver la lista acumulada
      {:return, pid} ->
        send(pid, list)

      #Un nuevo número llega
      num ->
        #Crear un filtro dinámico para este número y enlazarlo al siguiente de la cadena
        loop(:filtro, num, spawn(fn -> loop(:cola, [num | list]) end))
    end
  end


  #Enviar números por la cadena de filtros
  defp criba([], next) do
    #Cuando ya no quedan números, pedimos la lista final de primos
    send(next, {:return, self()})
    receive do
      list -> list
    end
  end

  defp criba([h | t], next) do
    #Enviar cada número al primer filtro de la cadena
    send(next, h)
    criba(t, next)
  end


  #Función principal
  def primos(n) do
    #Crear la cola inicial vacía (primer proceso de la cadena)
    next = spawn(fn -> loop(:cola, []) end)

    #Enviar todos los números 2..n a la cadena de filtros
    criba(range(n), next)
    |> Enum.reverse()
  end
end
