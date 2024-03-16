defmodule DidWebTest do
  use ExUnit.Case
  doctest DidWeb

  describe "[resolve url]" do
    test "did with domain" do
      assert DidWeb.resolve_url("did:web:example.com") ==
               {:ok,
                %URI{
                  scheme: "https",
                  authority: "example.com",
                  host: "example.com",
                  path: "/.well-known/did.json",
                  port: 443
                }}
    end

    test "did with domain and port" do
      assert DidWeb.resolve_url("did:web:example.com%3A3000") ==
               {:ok,
                %URI{
                  scheme: "https",
                  authority: "example.com:3000",
                  host: "example.com",
                  path: "/.well-known/did.json",
                  port: 3000
                }}
    end

    test "did with domain and path" do
      assert DidWeb.resolve_url("did:web:example.com:some:path") ==
               {:ok,
                %URI{
                  scheme: "https",
                  authority: "example.com",
                  host: "example.com",
                  path: "/some/path/did.json",
                  port: 443
                }}
    end

    test "did with domain, port and path" do
      assert DidWeb.resolve_url("did:web:example.com%3A3000:some:path") ==
               {:ok,
                %URI{
                  scheme: "https",
                  authority: "example.com:3000",
                  host: "example.com",
                  path: "/some/path/did.json",
                  port: 3000
                }}
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

    test "did url with fragment" do
      {result, _} = DidWeb.resolve("did:web:example.com/some/path#fragment")
      assert result == :error
    end

    test "invalid option" do
      {result, _} = DidWeb.resolve("", doh: :foobar)
      assert result == :error
    end
  end
end
