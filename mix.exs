defmodule ExSharp.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_sharp,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description,
     package: package,
     deps: deps]
  end
  
  def application do
    [applications: [:logger, :porcelain],
     mod: {ExSharp, []}]
  end
  
  defp deps do
    [{:porcelain, "~> 2.0"},
     {:exprotobuf, "~> 1.0"}]
  end
  
  defp description do
  """
  Call C# code from Elixir!
  """
  end
  
  defp package do
    [
     maintainers: ["Sam Schneider"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/sschneider1207/ex_sharp"}]
  end
end
