defmodule ExSharp.Roslyn do
  use GenServer
  @script_extension ".csx"
  @asm_extension ".dll"
  @cs_src "priv"
  @timeout_ms 1000
  
  # Client
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end
  
  def load_script(server, path) do
    path
    |> validate_ext(:script)
    |> validate_exists(:script)
    GenServer.cast(server, {:load_script, path})
  end
  
  def load_assembly(server, path) do
    path
    |> validate_ext(:asm)
    |> validate_exists(:asm)    
    GenServer.cast(server, {:load_asm, path})
  end
  
  def send_receive(server, data, timeout \\ @timeout_ms) do
    GenServer.call(server, {:send_receive, data, timeout})
  end
  
  def send_proto_receive_proto(server, proto, timeout \\ @timeout_ms) do
    GenServer.call(server, {:send_proto_receive_proto, proto, timeout})
  end
  def send_data_receive_proto(server, data, timeout \\ @timeout_ms) do
    GenServer.call(server, {:send_data_receive_proto, data, timeout})
  end
  
  def send(server, data) do
    GenServer.cast(server, {:send, data})
  end
  
  # Server
  
  def init([]) do
    roslyn_path
    |> open_port
    |> to_init_state
  end
  
  def handle_call({:send_receive, data, timeout}, _from, %{pid: pid} = state) do
    send_input(state.proc, <<byte_size(data) :: 32>> <> data)
    result = receive do
      {^pid, :data, :out, data} -> String.rstrip(data)
    after
      timeout -> nil
    end
    {:reply, result, state}
  end
  def handle_call({:send_data_receive_proto, data, timeout}, _from, %{pid: pid} = state) do
    send_input(state.proc, <<byte_size(data) :: 32>> <> data)
    result = receive do
      {^pid, :data, :out, <<112, 198, 7, 27, data :: binary>>} -> data
    after
      timeout -> nil
    end
    {:reply, result, state}
  end
  def handle_call({:send_proto_receive_proto, data, timeout}, _from, %{pid: pid} = state) do
    send_input(state.proc, <<112, 198, 7, 27, byte_size(data) :: 32>> <> data)
    result = receive do
      {^pid, :data, :out, <<112, 198, 7, 27, data :: binary>>} -> data
    after
      timeout -> nil
    end
    {:reply, result, state}
  end
  
  def handle_cast({:load_script, path}, state) do
    send_input(state.proc, ~s(#load "#{path}"))
    {:noreply, state}
  end
  def handle_cast({:load_asm, path}, state) do
    send_input(state.proc, ~s(#r "#{path}"))
    {:noreply, state}
  end  
  def handle_cast({:send, data}, state) do
    send_input(state.proc, data)    
    {:noreply, state}
  end
  
  def handle_info({pid, :data, :out, data}, %{pid: pid} = state) do
    require Logger
    data
    |> String.split("\r\n", trim: true)
    |> Enum.each(&IO.inspect(&1))
    {:noreply, state}
  end
  def handle_info({pid, :data, :err, error}, %{pid: pid} = state) do
    {:noreply, state}
  end
  def handle_info({pid, :result, result}, %{pid: pid} = state) do
    {:noreply, state}
  end
  
  # Private
  
  defp roslyn_path, do: System.find_executable("csi.exe")
  
  defp open_port(nil), do: raise ExSharpException, message: "Unable to locate csi.exe"
  defp open_port(path), do: Porcelain.spawn(path, [], in: :receive, out: {:send, self()})
  
  defp to_init_state(%Porcelain.Process{pid: pid} = proc), do: {:ok, %{pid: pid, proc: proc}}
  
  defp send_input(%Porcelain.Process{} = proc, data) do
    unless String.ends_with?(data, ["\n", "\r\n"]) do
      data = data <> "\r\n"
    end
    Porcelain.Process.send_input(proc, data)
  end
  
  defp validate_ext(path, :script) do
    unless Path.extname(path) == @script_extension do
      raise ExSharpException, message: "Invalid script extension"
    end
    path
  end  
  defp validate_ext(path, :asm) do
    unless Path.extname(path) == @asm_extension do
      raise ExSharpException, message: "Invalid assembly extension"
    end
    path
  end
  
  defp validate_exists(path, :script) do
    unless File.exists?(path) do
      raise ExSharpException, message: "Unable to locate script"
    end
    path
  end
  defp validate_exists(path, :asm) do
    unless File.exists?(path) do
      raise ExSharpException, message: "Unable to locate assembly"
    end
    path
  end
end