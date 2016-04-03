using System;
using ExSharp;
using System.Linq;

[ExSharpModule("Foo")]
public static class Foo 
{
  [ExSharpFunction("pi", 0)]
  public static ElixirTerm Pi(ElixirTerm[] argv, int argc) 
  {
    return ElixirTerm.MakeList(new ElixirTerm[]{
      ElixirTerm.MakeInt(1),
      ElixirTerm.MakeInt(2)
    });
  }
}

var runner = new ExSharp.Runner();
runner.Run();