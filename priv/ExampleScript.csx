using System;
using ExSharp;
using System.Linq;

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
  
  [ExSharpFunction("print_pid", 1)]
  public static ElixirTerm GetNode(ElixirTerm[] argv, int argc) 
  {
    var pid = ElixirTerm.GetPID(argv[0]);
    return ElixirTerm.MakeUTF8String(pid.ToString());
  }
  
  [ExSharpFunction("echo_ref", 1)]
  public static ElixirTerm GetRefNode(ElixirTerm[] argv, int argc) 
  {
    var @ref = ElixirTerm.GetReference(argv[0]);
    return ElixirTerm.MakeRef(@ref);
  }
  
  [ExSharpFunction("ref_equals", 2)]
  public static ElixirTerm RefEquals(ElixirTerm[] argv, int argc) 
  {
    var @ref1 = ElixirTerm.GetReference(argv[0]);
    var @ref2 = ElixirTerm.GetReference(argv[1]);
    
    var hash1 = @ref1.GetHashCode();
    var hash2 = @ref2.GetHashCode();
    var e = hash1 == hash2;
    return ElixirTerm.MakeAtom(e.ToString());
  }
  
  [ExSharpFunction("tuple", 0)]
  public static ElixirTerm Tuple(ElixirTerm[] argv, int argc) 
  {
    var size = 256;
    var elems = new ElixirTerm[]{ElixirTerm.MakeAtom("error"), ElixirTerm.MakeUTF8String("invalid blah")};
    return ElixirTerm.MakeTuple(elems);
  }
}

var runner = new ExSharp.Runner();
runner.Run();