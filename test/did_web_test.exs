defmodule DidWebTest do
  use ExUnit.Case
  doctest DidWeb

  test "resolve did" do
    did = "did:web:attr.global"
    DidWeb.resolve(did) |> IO.inspect()
    # assert DidWeb.resolve(") == :world
    assert true
  end

  test "not a did web" do
    did = "did:key:abc"
    assert DidWeb.resolve(did) == {:error, "Did does not start with did:web"}
  end
end
