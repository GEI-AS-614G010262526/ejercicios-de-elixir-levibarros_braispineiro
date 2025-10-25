defmodule MicroBankTest do
  use ExUnit.Case
  doctest MicroBank

  setup do
    start_supervised!({MicroBank.Supervisor, %{alice: 100, bob: 50}})
    :ok
  end

  @tag :saldo
  test "consultar saldo existente" do
    assert MicroBank.ask(:alice) == {:ok, 100}
  end

  @tag :error
  test "consultar saldo de cuenta inexistente devuelve error" do
    assert MicroBank.ask(:carla) == {:error, :no_cuenta}
  end

  @tag :deposito
  test "depositar dinero incrementa el saldo" do
    assert MicroBank.deposit(:bob, 20) == {:ok, 70}
    assert MicroBank.ask(:bob) == {:ok, 70}
  end

  @tag :retiro
  test "retirar dinero reduce el saldo correctamente" do
    assert MicroBank.withdraw(:alice, 50) == {:ok, 50}
    assert MicroBank.ask(:alice) == {:ok, 50}
  end

  @tag :error
  test "no se puede retirar más de lo disponible" do
    assert MicroBank.withdraw(:bob, 200) == {:error, :saldo_insuficiente}
  end

  @tag :supervisor
  test "el supervisor reinicia el servidor si este falla" do
    pid_original = Process.whereis(MicroBank)

    # Simulamos un fallo grave del proceso
    Process.exit(pid_original, :kill)

    # Damos un pequeño tiempo para que el supervisor reinicie
    :timer.sleep(100)

    pid_nuevo = Process.whereis(MicroBank)

    assert pid_original != pid_nuevo
    assert Process.alive?(pid_nuevo)
  end

  @tag :validaciones
  test "no se pueden depositar montos negativos" do
    assert_raise FunctionClauseError, fn ->
      MicroBank.deposit(:alice, -50)
    end
  end

  @tag :validaciones
  test "no se pueden retirar montos negativos" do
    assert_raise FunctionClauseError, fn ->
      MicroBank.withdraw(:bob, -10)
    end
  end
end

