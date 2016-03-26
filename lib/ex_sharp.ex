defmodule ExSharp do
  use Application
  alias ExSharp.Roslyn
  alias ExSharp.Messages.{ModuleSpec, ModuleList, FunctionCall, FunctionResult}
  @roslyn Roslyn
  @ex_sharp_dll Path.expand("../priv/ExSharp.dll", __DIR__)
  @send_mod_list_cmd <<203, 61, 10, 114>>
  @atom_encoding :utf8

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [
      worker(@roslyn, [[name: @roslyn]])
    ]
    opts = [strategy: :one_for_one, name: ExSharp.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  @doc """
  Defines modules and functions based on a `.csx` script file.
  Best utilized in an `@on_load` module hook.
    
  ## Examples
  
    defmodule Foo do
      @on_load  :load_csx
      
      def load_csx do
        ExSharp.load_csx("path/to/foo.csx")
      end
    end
    
  ## Generated Code
      
  Given the following C# code:
  
    [ExSharpModule("Foo")]
    public static class Foo 
    {
      [ExSharpFunction("bar", 0)]
      public static ElixirTerm Bar(ElixirTerm[] argc, int argv) 
      {
        ...
      }
      
      [ExSharpFunction("baz", 1)]
      public static ElixirTerm Baz(ElixirTerm[] argc, int argv) 
      {
        ...
      }
    }
    
  The following functions will become available:
  
    * &Foo.bar/0
    * &Foo.baz/1      
  """
  def load_csx(path) do
    Roslyn.load_assembly(@roslyn, @ex_sharp_dll)
    Roslyn.load_script(@roslyn, path)
    
    Roslyn.send_data_receive_proto(@roslyn, @send_mod_list_cmd)
    |> ModuleList.decode
    |> init_modules
  end
  
  defp init_modules(%ModuleList{} = mod_list) do
    for module <- mod_list.modules, do: module |> init_module
    :ok
  end
  
  defp init_module(%ModuleSpec{} = mod_spec) do
    fun_defs = get_functions(mod_spec.functions)
    ~s"""
      defmodule #{mod_spec.name} do
        #{fun_defs}
      end
    """
    |> Code.eval_string
    :ok
  end
  
  defp get_functions(funs) when is_list(funs) do
    funs
    |> Enum.map(&def_function/1)
    |> Enum.join("\n")
  end
  
  defp def_function(%ModuleSpec.Function{} = fun) do  
    vars = get_vars(fun.arity)
    ~s"""
      def #{fun.name}(#{vars}) do
        ExSharp.call_cs_method(__MODULE__, "#{fun.name}", [#{vars}])
      end
    """
  end
  
  defp get_vars(nil), do: ""
  defp get_vars(arity) when arity > 0 do
    (for n <- 1..arity, do: "var#{n}")
    |> Enum.join(", ")
  end
  defp get_vars(_), do: raise ExSharpException, message: "Cannot define function with negative arity"
  
  @doc """
  Attempts to call a C#
  """
  def csharp_apply(module, fun, args) do
    data = 
      FunctionCall.new(
        moduleName: :erlang.atom_to_binary(module, @atom_encoding), 
        functionName: fun, 
        argc: length(args), 
        argv: encode_argv(args))
      |> FunctionCall.encode

    Roslyn.send_proto_receive_proto(@roslyn, data)
    |> FunctionResult.decode
    |> parse_result
  end
  
  defp encode_argv(argv) do
    argv
    |> Enum.map(&:erlang.term_to_binary/1)
  end
  
  defp parse_result(%FunctionResult{value: value}), do: :erlang.binary_to_term(value)
end

defmodule ExSharpException do
  defexception [message: ""]
end
