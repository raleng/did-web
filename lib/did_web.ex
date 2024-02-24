defmodule DidWeb do
  @moduledoc """
  This module contains functions to resolve a Web DID.
  """

  @doc """
  Resolves the URL from a Web DID, gets the DID document from the URL, and validates the return DID document.

  Currently, only the DID document "id" is validated to be equal to the provided Web DID.

  Returns the resolved DID document or an error.

  ## Examples

      > DidWeb.resolve("did:web:example.com)
      {:ok, did_document}
  """
  @doc since: "0.1.0"
  def resolve(did) do
    with {:ok, url} <- resolve_url(did),
         {:ok, %{body: did_document}} <- Req.get(url),
         {:ok, did_document} <- validate(did, did_document) do
      {:ok, did_document}
    else
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Resolve the URL of a Web DID.

  Returns the resolved URL or an error.

  ## Examples

      iex> DidWeb.resolve_url("did:web:example.com")
      {:ok, "https://example.com/.well-known/did.json"}

      iex> DidWeb.resolve_url("did:web:example.com%3A3000:some:path")
      {:ok, "https://example.com:3000/some/path/did.json"}
  """
  @doc since: "0.1.0"
  def resolve_url(did)
  def resolve_url("did:web:" <> domain_path) do
    domain_path_decoded = domain_path |> String.replace(":", "/") |> URI.decode()
    url = URI.parse("https://#{domain_path_decoded}")

    case url do
      %{host: nil} -> {:error, "Not a valid URL: #{url}"}
      %{path: nil} -> {:ok, "#{URI.to_string(url)}/.well-known/did.json"}
      url -> {:ok, "#{URI.to_string(url)}/did.json"}
    end
  end

  def resolve_url(_), do: {:error, "DID does not start with 'did:web:'"}

  defp validate(did, did_document) do
    if did != did_document["id"] do
      {:error, "DID document id does not match requested DID"}
    else
      {:ok, did_document}
    end
  end
end
