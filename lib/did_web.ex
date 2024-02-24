defmodule DidWeb do
  @moduledoc """
  Documentation for `DidWeb`.
  """

  @doc """
  Hello world.
  """
  def resolve("did:web:" <> domain_path) do
    with {:ok, url} = resolve_domain_path(domain_path),
         {:ok, %{body: did_document}} = Req.get(url),
         {:ok, did_document} = validate(did_document) do
      did_document
    end
  end

  def resolve(_), do: {:error, "Did does not start with did:web"}

  defp resolve_domain_path(domain_path) do
    domain_path_decoded = domain_path |> String.replace(":", "/") |> URI.decode()
    url = URI.parse("https://#{domain_path_decoded}")

    case url do
      %{host: nil} -> {:error, "Not a valid URL: #{url}"}
      %{path: nil} -> {:ok, "#{URI.to_string(url)}/.well-known/did.json"}
      url -> {:ok, "#{URI.to_string(url)}/did.json"}
    end
  end

  defp validate(did_document) do
    {:ok, did_document}
  end
end
