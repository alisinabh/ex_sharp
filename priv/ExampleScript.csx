using System;
using ExSharp;

[ExSharpModule("Example")]
public static class ExampleModule
{
  [ExSharpFunction("foo", 0)]
  public static ElixirTerm Foo(ElixirTerm[] argv, int argc)
  {
    return ElixirTerm.MakeAtom("foo");
  }
  
  [ExSharpFunction("double", 0)]
  public static ElixirTerm Pi(ElixirTerm[] argv, int argc)
  {
    return ElixirTerm.MakeDouble(3.14);
  }
  
  [ExSharpFunction("echo_atom", 1)]
  public static ElixirTerm EchoAtom(ElixirTerm[] argv, int argc)
  {
    var atom = ElixirTerm.GetAtom(argv[0]);
    return ElixirTerm.MakeAtom(atom+"_booyah");
  }
}

var runner = new ExSharp.ExSharpRunner();
runner.Run();