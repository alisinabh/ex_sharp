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

var runner = new ExSharp.ExSharpRunner();
runner.Run();