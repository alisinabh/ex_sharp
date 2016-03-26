defmodule ExSharp.Messages do
  use Protobuf, from: Path.expand("../../priv/ExSharp.proto", __DIR__)
end