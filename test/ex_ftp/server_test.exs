defmodule ExFTP.ServerTest do
  use ExUnit.Case

  doctest ExFTP.Server
  @moduletag :capture_log
  test "accepts tcp connections" do
    %{active: active_children} = DynamicSupervisor.count_children(ExFTP.WorkerSupervisor)
    port = Application.get_env(:ex_ftp, :ftp_port)
    assert {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:inet, :binary])

    # give worker time to start up
    Process.sleep(100)

    %{active: now_active_children} = DynamicSupervisor.count_children(ExFTP.WorkerSupervisor)
    assert active_children + 1 == now_active_children

    :gen_tcp.close(socket)
  end
end
