defmodule ExSharp do
  alias ExSharp.Roslyn
  alias ExSharp.Messages.{ModuleSpec, ModuleList, FunctionCall, FunctionResult}
  @atom_encoding :utf8
  
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
  def init_modules(nil, _roslyn), do: :ok
  def init_modules(%ModuleList{} = mod_list, roslyn) do
    for module <- mod_list.modules, do: init_module(module, roslyn)
    :ok
  end
  
  defp init_module(%ModuleSpec{} = mod_spec, roslyn) do
    fun_defs = function_defs(mod_spec.functions)
    ~s"""
      defmodule #{mod_spec.name} do
        @roslyn roslyn
        #{fun_defs}
      end
    """
    |> Code.eval_string([roslyn: roslyn])
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
        ExSharp.csharp_apply(@roslyn, __MODULE__, "#{fun.name}", [#{vars}])
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
  def csharp_apply(roslyn, module, fun, args) do
    build_function_call(module, fun, args)
    |> send_function_call(roslyn)
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
  
  defp send_function_call(%FunctionCall{} = call, roslyn), do: Roslyn.function_call(roslyn, call)
  
  defp parse_result(%FunctionResult{value: value}), do: :erlang.binary_to_term(value)
end

defmodule ExSharpException do
  defexception [message: ""]
end
