using System;
using ExSharp;
using System.Linq;
using static ExSharp.Runner;

[ExSharpModule("Foo")]
public static class Foo 
{
  [ExSharpFunction("pi", 1)]
  public static void Pi(ElixirTerm[] argv, int argc) 
  {    
    var fun = argv[0];
    
    ElixirCallback(fun, new ElixirTerm[0]);    
  }
}

var runner = new ExSharp.Runner();
await runner.Run();