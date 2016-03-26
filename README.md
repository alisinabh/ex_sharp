# ExSharp

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add ex_sharp to your list of dependencies in `mix.exs`:

        def deps do
          [{:ex_sharp, "~> 0.0.1"}]
        end

  2. Ensure ex_sharp is started before your application:

        def application do
          [applications: [:ex_sharp]]
        end
        
## Usage
  
Using the following C# code in `foo.csx`:
 
      using System;
      using ExSharp;
      
      [ExSharpModule("Foo")]
      public static class Foo 
      {
        [ExSharpFunction("pi", 0)]
        public static ElixirTerm Pi(ElixirTerm[] argv, int argc) 
        {
          return ElixirTerm.MakeDouble(3.14159);
        }
        
        [ExSharpFunction("echo", 1)]
        public static ElixirTerm Baz(ElixirTerm[] argv, int argc) 
        {
          var str = ElixirTerm.GetUTF8String(argv[0]);
          return ElixirTerm.MakeUTF8String($"from csharp: {str}");
        }
      }
      
      var runner = new ExSharp.Runner();
      runner.Run();
        
And a module with the following structure:

      defmodule Foo do
        @on_load  :load_csx
    
        def load_csx do
          ExSharp.load_csx("path/to/foo.csx")
        end
      end
  
The following functions will become available at runtime:
  
  1. Foo.pi/0
  2. Foo.echo/1
  
  

