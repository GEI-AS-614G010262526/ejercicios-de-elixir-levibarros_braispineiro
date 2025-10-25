defmodule Trabajador do
  def start() do
    spawn(fn -> loop() end)
  end

  defp loop() do
    receive do
      {:trabajo, from, func, idx} ->
        result = func.()
        send(from, {:resultado, self(), idx, result})
        loop()

      :stop ->
        :ok
    end
  end
end


defmodule Servidor do
  @spec start(integer()) :: {:ok, pid()}
  def start(n) when is_integer(n) and n > 0 do
    pid = spawn(fn -> init(n) end)
    {:ok, pid}
  end

  @spec run_batch(pid(), list()) :: list()
  def run_batch(master, jobs) when is_list(jobs) do
    ref = make_ref()
    send(master, {:trabajos, self(), ref, jobs})

    receive do
      {:respuesta, ^ref, result} ->
        result
    end
  end

  @spec stop(pid()) :: :ok
  def stop(master) do
    send(master, {:stop, self()})

    receive do
      {:ok, ^master} -> :ok
    end
  end

  defp init(n) do
    workers = for _ <- 1..n, do: Trabajador.start()
    loop(workers)
  end

  defp loop(workers) do
    receive do
      {:trabajos, from, ref, jobs} ->
        if length(jobs) > length(workers) do
          send(from, {:respuesta, ref, {:error, :lote_demasiado_grande}})
          loop(workers)
        else
          Enum.with_index(jobs)
          |> Enum.each(fn {{func, idx}, i} ->
            worker = Enum.at(workers, i)
            send(worker, {:trabajo, self(), func, idx})
          end)

          final_results = collect_results(%{}, length(jobs))

          ordered =
            final_results
            |> Enum.sort_by(fn {idx, _val} -> idx end)
            |> Enum.map(fn {_idx, val} -> val end)

          send(from, {:respuesta, ref, ordered})
          loop(workers)
        end

      {:stop, from} ->
        Enum.each(workers, fn w -> send(w, :stop) end)
        send(from, {:ok, self()})
    end
  end

  defp collect_results(acc, 0), do: acc

  defp collect_results(acc, remaining) do
    receive do
      {:resultado, _worker, idx, result} ->
        collect_results(Map.put(acc, idx, result), remaining - 1)
    end
  end

  # ========= PRUEBAS =========

  def pruebas() do
    IO.puts(">>> Prueba 1: lote simple")
    {:ok, master} = Servidor.start(3)

    jobs = [
      fn -> 1 + 1 end,
      fn -> 2 * 5 end,
      fn -> String.upcase("hola") end
    ]

    IO.inspect Servidor.run_batch(master, Enum.with_index(jobs))
    # Esperado: [2, 10, "HOLA"]

    IO.puts(">>> Prueba 2: lote demasiado grande")
    jobs2 = [
      fn -> 1 + 1 end,
      fn -> 2 + 2 end,
      fn -> 3 + 3 end
    ]

    IO.inspect Servidor.run_batch(master, Enum.with_index(jobs2))
    # Esperado: {:error, :lote_demasiado_grande}

    IO.puts(">>> Prueba 3: orden de resultados")
    jobs3 = [
      fn -> :timer.sleep(300); :a end,
      fn -> :timer.sleep(100); :b end,
      fn -> :timer.sleep(200); :c end
    ]

    IO.inspect Servidor.run_batch(master, Enum.with_index(jobs3))
    # Esperado: [:a, :b, :c]

    IO.puts(">>> Parando servidor")
    IO.inspect Servidor.stop(master)
  end
end
