defmodule FTP2Cloud.ServerTest do
  use ExUnit.Case
  doctest FTP2Cloud.Server

  test "accepts tcp connections" do
    %{active: active_children} = DynamicSupervisor.count_children(FTP2Cloud.WorkerSupervisor)

    assert {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, 4041, [:inet, :binary])

    # give worker time to start up
    Process.sleep(100)

    %{active: now_active_children} = DynamicSupervisor.count_children(FTP2Cloud.WorkerSupervisor)
    assert active_children + 1 == now_active_children

    :gen_tcp.close(socket)
  end
end
