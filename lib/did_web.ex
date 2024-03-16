defmodule DidWeb do
  @moduledoc """
  This module contains functions to resolve a Web DID.
  """

  @doc """
  Resolves the URL from a Web DID, gets the DID document from the URL, and validates the returned DID document.

  Returns the resolved DID document or an error.

  ## Options

  - `:doh`: The Web DID specification recommends using DNS over HTTPS (DoH). DoH is not enabled by default, and currently only the Cloudflare DoH service is supported. In case you want to use a different DoH service, you can use the `resolve_url/1` function to do the HTTP request yourself.

    Possible values: `:none` (default), `:cloudflare`

  ## Validation

  The "id" of the resolved DID document is validated to be equal to the provided Web DID.

  ## Examples

      # Default HTTPS request

      > DidWeb.resolve("did:web:example.com")
      {:ok, did_document}

      # Request using Cloudflares DNS over HTTPS service

      > DidWeb.resolve("did:web:example.com", doh: :cloudflare)
      {:ok, did_document}
  """
  @doc since: "0.1.0"
  @spec resolve(did :: String.t(), options :: keyword()) ::
          {:ok, map()}
          | {:error, {:options_error, String.t()}}
          | {:error, {:input_error, String.t()}}
          | {:error, {:dns_error, String.t()}}
          | {:error, {:http_error, String.t()}}
          | {:error, {:json_error, String.t()}}
          | {:error, {:validation_error, String.t()}}
  def resolve(did, options \\ [doh: :none]) do
    with {:ok, options} <- validate_options(options),
         {:ok, url} <- resolve_url(did),
         {:ok, did_document} <- get_did_document(url, options[:doh]),
         {:ok, did_document} <- validate(did, did_document) do
      {:ok, did_document}
    end
  end

  @doc """
  Resolve the URL of a Web DID.

  Returns the resolved URL or an error.

  ## Examples

      iex> DidWeb.resolve_url("did:web:example.com")
      {:ok, %URI{scheme: "https", authority: "example.com", host: "example.com", path: "/.well-known/did.json", port: 443}}

      iex> DidWeb.resolve_url("did:web:example.com%3A3000:some:path")
      {:ok, %URI{scheme: "https", authority: "example.com:3000", host: "example.com", path: "/some/path/did.json", port: 3000}}

      iex> DidWeb.resolve_url("did:web:notaurl")
      {:error, {:input_error, "Not a valid URL: https://notaurl"}}
  """
  @doc since: "0.1.0"
  @spec resolve_url(did :: String.t()) :: {:ok, URI.t()} | {:error, {:input_error, String.t()}}
  def resolve_url(did)

  def resolve_url("did:web:" <> domain_path) do
    url =
      domain_path
      |> String.replace(":", "/")
      |> URI.decode()
      |> then(&("https://" <> &1))
      |> URI.parse()

    validHost = url.host =~ "."

    case url do
      %{fragment: fragment} when fragment != nil ->
        {:error, {:input_error, "URL contains a fragment"}}

      %{host: host} when host == nil or not validHost ->
        {:error, {:input_error, "Not a valid URL: #{url}"}}

      %{path: nil} ->
        {:ok, URI.append_path(url, "/.well-known/did.json")}

      url ->
        {:ok, URI.append_path(url, "/did.json")}
    end
  end

  def resolve_url(_), do: {:error, {:input_error, "DID does not start with 'did:web:'"}}

  @spec validate_options(options :: keyword()) ::
          {:ok, keyword()} | {:error, {:options_error, String.t()}}
  defp validate_options(options) do
    options |> IO.inspect()

    with {:ok, options} <- Keyword.validate(options, doh: :none),
         valid_doh = Enum.member?([:none, :cloudflare], options[:doh]) do
      if valid_doh do
        {:ok, options}
      else
        {:error,
         {:options_error,
          "Invalid DoH option provided. Must be :none or :cloudflare, but was '#{options[:doh]}'"}}
      end
    else
      {:error, invalid_options} ->
        {:error, {:options_error, "Invalid options provided: #{invalid_options}"}}
    end
  end

  @spec get_did_document(url :: URI.t(), doh :: atom()) ::
          {:ok, HTTPoison.Response.t()}
          | {:error, {:dns_error, String.t()}}
          | {:error, {:http_error, String.t()}}
          | {:error, {:json_error, String.t()}}
  defp get_did_document(url, :none) do
    url
    |> URI.to_string()
    |> HTTPoison.get([], follow_redirect: true)
    |> decode_response_body
  end

  defp get_did_document(url, :cloudflare) do
    with {:ok, resolved_ip} <- dns_over_https(url),
         resolve_option = {:resolve, [{url.host, 443, resolved_ip}]} do
      url
      |> URI.to_string()
      |> HTTPoison.get([], follow_redirect: true, hackney: [options: [resolve_option]])
      |> decode_response_body
    end
  end

  @spec dns_over_https(url :: URI.t()) :: {:ok, String.t()} | {:error, {:dns_error, String.t()}}
  defp dns_over_https(url) do
    dns_over_https_url = "https://cloudflare-dns.com/dns-query?name=#{url.host}"

    response =
      dns_over_https_url
      |> HTTPoison.get(Accept: "application/dns-json")
      |> decode_response_body

    with {:ok, %{"Answer" => answer}} <- response,
         %{"data" => resolved_ip} <- Enum.find(answer, &(&1["type"] == 1)) do
      {:ok, resolved_ip}
    else
      {:ok, _} ->
        {:error, {:dns_error, "DNS resolution faild to return an 'Answer'"}}

      {:error, message} ->
        {:error, {:dns_error, message}}

      nil ->
        {:error, {:dns_error, "DNS resolution failed, no A name record found"}}
    end
  end

  @spec validate(did :: String.t(), did_document :: any()) ::
          {:ok, any()} | {:error, {:validation_error, String.t()}}
  defp validate(did, did_document) do
    if did != did_document["id"] do
      {:error, {:validation_error, "DID document id does not match requested DID"}}
    else
      {:ok, did_document}
    end
  end

  @spec decode_response_body(
          response :: {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
        ) ::
          {:ok, term()}
          | {:error, {:http_error, String.t()}}
          | {:error, {:json_error, String.t()}}
  defp decode_response_body(response) do
    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- response,
         {:ok, decoded} <- Jason.decode(body) do
      {:ok, decoded}
    else
      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, {:http_error, "Failed to get DID document with HTTP status code #{code}"}}

      {:error, error} when is_map(error) and error.__struct__ == HTTPoison.Error ->
        {:error,
         {:http_error,
          "Failed to get DID document with request error: #{HTTPoison.Error.message(error)}"}}

      {:error, error} when is_map(error) and error.__struct__ == Jason.DecodeError ->
        {:error,
         {:json_error, "Failed to decode DID document: #{Jason.DecodeError.message(error)}"}}
    end
  end
end
