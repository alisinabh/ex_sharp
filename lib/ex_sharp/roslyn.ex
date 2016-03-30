defmodule ExSharp.Roslyn do
  use GenServer
  @script_extension ".csx"
  @asm_extension ".dll"
  @default_timeout_ms 5000
  @timeout_ms Application.get_env(:ex_sharp, :timeout, @default_timeout_ms)
  @send_mod_list_cmd <<203, 61, 10, 114>>
  @proto_header <<112, 198, 7, 27>>
  alias ExSharp.Messages.{ModuleList, FunctionCall, FunctionResult}
  
  # Client
  
  def start_link(ex_sharp_path, csx_path, opts \\ []) do
    GenServer.start_link(__MODULE__, [ex_sharp_path, csx_path], opts)
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
  
  def function_call(server, %FunctionCall{} = call) do
    GenServer.call(server, {:func_call, call})
  end
  
  # Server
  
  def init([ex_sharp_path, nil]) do
    proc = open_port(roslyn_path, ex_sharp_path, nil)
    {:ok, %{proc: proc, pid: proc.pid}}
  end
  def init([ex_sharp_path, csx_path]) do
    proc = open_port(roslyn_path, ex_sharp_path, csx_path)      
    send_receive_proto(proc, @send_mod_list_cmd, ModuleList)
    |> ExSharp.init_modules
    {:ok, %{proc: proc, pid: proc.pid}}
  end
  
  def handle_call({:func_call, call}, _from, state) do
    encoded = FunctionCall.encode(call)
    data = @proto_header <> <<byte_size(encoded) :: 32>> <> encoded
    result = send_receive_proto(state.proc, data, FunctionResult)
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
  
  defp open_port(nil, _ex_sharp_path, _csx_path), do: raise ExSharpException, message: "Unable to locate csi.exe"
  defp open_port(path, ex_sharp_path, nil), do: Porcelain.spawn(path, ["/r:#{ex_sharp_path}"], in: :receive, out: {:send, self()})
  defp open_port(path, ex_sharp_path, csx_path), do: Porcelain.spawn(path, ["/r:#{ex_sharp_path}", csx_path], in: :receive, out: {:send, self()})
  
  defp send_receive_proto(%Porcelain.Process{pid: pid} = proc, data, message_module) do
    send_input(proc, data)
    receive do
      {^pid, :data, :out, @proto_header <> data } -> message_module.decode(data)
    after
      @timeout_ms -> nil
    end
  end
  
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