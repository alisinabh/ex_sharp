defmodule ExSharp.Roslyn do
  use GenServer  
  alias ExSharp.Messages.{ModuleList, FunctionCall, FunctionResult, ElixirCallback}
  @ex_sharp_path Path.expand("../../priv/ExSharp.dll", __DIR__)
  @default_timeout_ms 5000
  @timeout_ms Application.get_env(:ex_sharp, :timeout, @default_timeout_ms)
  @inspect_stdio Application.get_env(:ex_sharp, :inspect_stdio, false)
  @start_signal <<37, 10, 246, 113>>
  @send_mod_list_cmd <<203, 61, 10, 114>>
  @proto_header <<112, 198, 7, 27>>
  @callback_header <<177, 229, 171, 48>>
  
  # Client
  
  def start_link(csx_path, opts \\ []) do
    GenServer.start_link(__MODULE__, [csx_path], opts)
  end
  
  def function_call(server, %FunctionCall{} = call) do
    GenServer.call(server, {:func_call, call})
  end
  
  # Server
  
  def init([csx_path]) do
    proc = open_port(roslyn_path, csx_path)    
    receive_start_signal(proc)  
    |> send_receive_proto(@send_mod_list_cmd, ModuleList)
    |> ExSharp.init_modules(self)
    {:ok, %{proc: proc, pid: proc.pid}}
  end
  
  def handle_call({:func_call, call}, _from, state) do
    encoded = FunctionCall.encode(call)
    data = @proto_header <> <<byte_size(encoded) :: 32>> <> encoded
    result = send_receive_proto(state.proc, data, FunctionResult)
    {:reply, result, state}
  end
  
  def handle_info({pid, :data, :out, @callback_header <> @proto_header <> data}, %{pid: pid} = state) do
    ElixirCallback.decode(data)
    |> apply_callback
    {:noreply, state}
  end
  def handle_info({pid, :data, :out, data}, %{pid: pid} = state) do
    if @inspect_stdio do
      data
      |> String.split("\r\n", trim: true)
      |> Enum.each(&IO.inspect(&1))
    end
    {:noreply, state}
  end
  def handle_info({pid, :data, :err, _error}, %{pid: pid} = state) do
    {:noreply, state}
  end
  def handle_info({pid, :result, _result}, %{pid: pid} = state) do
    {:noreply, state}
  end  
  
  # Private
  
  defp roslyn_path, do: System.find_executable("csi.exe")
  
  defp open_port(nil, _csx_path), do: raise "Unable to locate csi.exe"
  defp open_port(path, csx_path), do: Porcelain.spawn(path, ["/r:#{@ex_sharp_path}", csx_path], in: :receive, out: {:send, self()})
  
  defp receive_start_signal(%Porcelain.Process{pid: pid} = proc) do
    receive do
      {^pid, :data, :out, @start_signal } -> proc
      {^pid, :data, :out, data } -> raise "Unable to start Roslyn, #{data}"
    after
      @timeout_ms -> raise "Unable to start Roslyn, received no response."
    end    
  end
  
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
  
  defp apply_callback(%ElixirCallback{} = cb) do
    fun = :erlang.binary_to_term(cb.fun)
    args = Enum.map(cb.args, &:erlang.binary_to_term/1)
    apply(fun, args)
  end
end