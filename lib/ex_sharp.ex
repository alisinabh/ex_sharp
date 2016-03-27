defmodule ExSharp do
  use Application
  alias ExSharp.Roslyn
  alias ExSharp.Messages.{ModuleSpec, ModuleList, FunctionCall, FunctionResult}
  @roslyn Roslyn
  @ex_sharp_path Path.expand("../priv/ExSharp.dll", __DIR__)
  @csx_path Application.get_env(:ex_sharp, :csx_path)
  @atom_encoding :utf8

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [
      worker(@roslyn, [@ex_sharp_path, @csx_path, [name: @roslyn]])
    ]
    opts = [strategy: :one_for_one, name: ExSharp.Supervisor]
    sup = Supervisor.start_link(children, opts)
  end
  
  @doc """
  Defines modules and functions based on a `.csx` script file.
  Normally called indirectly by initializing a Roslyn process with a `.csx` file
  
  ## Generated Code
      
  Given the following C# code:
  
    [ExSharpModule("Foo")]
    public static class Foo 
    {
      [ExSharpFunction("bar", 0)]
      public static ElixirTerm Bar(ElixirTerm[] argv, int argc) 
      {
        ...
      }
      
      [ExSharpFunction("baz", 1)]
      public static ElixirTerm Baz(ElixirTerm[] argv, int argc) 
      {
        ...
      }
    }
    
  The following functions will become available:
  
    * &Foo.bar/0
    * &Foo.baz/1      
  """  
  def init_modules(%ModuleList{} = mod_list) do
    for module <- mod_list.modules, do: init_module(module)
    :ok
  end
  
  defp init_module(%ModuleSpec{} = mod_spec) do
    fun_defs = function_defs(mod_spec.functions)
    ~s"""
      defmodule #{mod_spec.name} do
        #{fun_defs}
      end
    """
    |> Code.eval_string
    :ok
  end
  
  defp function_defs(funs) when is_list(funs) do
    funs
    |> Enum.map(&def_function/1)
    |> Enum.join("\n")
  end
  
  defp def_function(%ModuleSpec.Function{} = fun) do  
    vars = get_vars(fun.arity)
    ~s"""
      def #{fun.name}(#{vars}) do
        ExSharp.csharp_apply(__MODULE__, "#{fun.name}", [#{vars}])
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
  Attempts to call a C# function
  """
  def csharp_apply(module, fun, args) do
    build_function_call(module, fun, args)
    |> send_function_call
    |> parse_result
  end
  
  defp build_function_call(module, fun, args) do
    FunctionCall.new(
      moduleName: :erlang.atom_to_binary(module, @atom_encoding), 
      functionName: fun, 
      argc: length(args), 
      argv: Enum.map(args, &:erlang.term_to_binary/1)
    )
  end
  
  defp send_function_call(%FunctionCall{} = call), do: Roslyn.function_call(@roslyn, call)
  
  defp parse_result(%FunctionResult{value: value}), do: :erlang.binary_to_term(value)
end

defmodule ExSharpException do
  defexception [message: ""]
end
