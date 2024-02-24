defmodule DidWebTest do
  use ExUnit.Case
  doctest DidWeb

  describe "[resolve url]" do
    test "did with domain" do
      assert DidWeb.resolve_url("did:web:example.com") ==
               {:ok, "https://example.com/.well-known/did.json"}
    end

    test "did with domain and port" do
      assert DidWeb.resolve_url("did:web:example.com%3A3000") ==
               {:ok, "https://example.com:3000/.well-known/did.json"}
    end

    test "did with domain and path" do
      assert DidWeb.resolve_url("did:web:example.com:some:path") ==
               {:ok, "https://example.com/some/path/did.json"}
    end

    test "did with domain, port and path" do
      assert DidWeb.resolve_url("did:web:example.com%3A3000:some:path") ==
               {:ok, "https://example.com:3000/some/path/did.json"}
    end

    test "random string" do
      {result, _} = DidWeb.resolve("abc")
      assert result == :error
    end

    test "not a did:web" do
      {result, _} = DidWeb.resolve("did:key:abc")
      assert result == :error
    end

    test "not a valid domain" do
      {result, _} = DidWeb.resolve("did:web:abc")
      assert result == :error
    end
  end
end
