using System;
using ExSharp;
using System.Linq;

[ExSharpModule("Foo")]
public static class Foo 
{
  [ExSharpFunction("pi", 0)]
  public static ElixirTerm Pi(ElixirTerm[] argv, int argc) 
  {
    throw new Exception("boo");
  }
}

var runner = new ExSharp.Runner();
runner.Run();