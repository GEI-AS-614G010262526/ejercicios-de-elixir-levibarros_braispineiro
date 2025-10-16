defmodule Eratostenes do

    #Creación de la lista de números

    def rango(n) when n >= 2 do
      rango(2,n)
    end

    def rango(n,n) do
      [n]
    end

    def rango(n,m) do
      [n | rango(n + 1, m)]
    end


    #Filtrado de números múltiplos de n

    def filtro_nums(n, [h|t]) when rem(h, n) == 0 do
      filtro_nums(n, t)
    end

    def filtro_nums(n, [h|t]) do
      [h | filtro_nums(n, t)]
    end

    def filtro_nums(_n, []) do
      []
    end


    #La criba

    def criba([h|t]) do
      [h | criba(filtro_nums(h, t))]
    end

    def criba([]) do
      []
    end

    def primos(n) do
      criba(rango(n))
    end




end
