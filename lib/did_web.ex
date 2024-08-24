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
    with {:ok, options} <- Keyword.validate(options, doh: :none) do
      if Enum.member?([:none, :cloudflare], options[:doh]) do
        {:ok, options}
      else
        error_msg =
          "Invalid DoH option provided. Must be :none or :cloudflare, but was '#{options[:doh]}'"

        {:error, {:options_error, error_msg}}
      end
    else
      {:error, invalid_options} ->
        {:error, {:options_error, "Invalid options provided: #{invalid_options}"}}
    end
  end

  @spec get_did_document(url :: URI.t(), doh :: atom()) ::
          {:ok, term()}
          | {:error, {:dns_error, String.t()}}
          | {:error, {:http_error, String.t()}}
          | {:error, {:json_error, String.t()}}
  defp get_did_document(url, :none) do
    with {:ok, %HTTPoison.Response{body: body}} <- http_get(url) do
      decode_response_body(body)
    end
  end

  defp get_did_document(url, :cloudflare) do
    with {:ok, options} <- dns_over_https_options(url),
         {:ok, %HTTPoison.Response{body: body}} <- http_get(url, options) do
      decode_response_body(body)
    end
  end

  @spec http_get(url :: URI.t(), options: keyword()) ::
          {:ok, HTTPoison.Response.t()} | {:error, {:http_error, String.t()}}
  defp http_get(url, options \\ []) do
    http_response =
      url
      |> URI.to_string()
      |> HTTPoison.get([], follow_redirect: true, hackney: options)

    case http_response do
      {:ok, %HTTPoison.Response{status_code: 200} = response} ->
        {:ok, response}

      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, {:http_error, "Failed to get DID document with HTTP status code #{code}"}}

      {:error, error} ->
        error_msg =
          "Failed to get DID document with request error: #{HTTPoison.Error.message(error)}"

        {:error, {:http_error, error_msg}}
    end
  end

  @spec dns_over_https_options(url :: URI.t()) ::
          {:ok, keyword()}
          | {:error, {:dns_error, String.t()}}
          | {:error, {:http_error, String.t()}}
  defp dns_over_https_options(url) do
    dns_over_https_url = "https://cloudflare-dns.com/dns-query?name=#{url.host}"

    with {:ok, body} <- http_get_dns(dns_over_https_url),
         {:ok, decoded} <- decode_response_body(body),
         {:ok, ip} <- get_ip(decoded) do
      {:ok, [options: [{:resolve, [{url.host, 443, ip}]}]]}
    end
  end

  @spec http_get_dns(url :: String.t()) ::
          {:ok, term()} | {:error, {:dns_error, String.t()}} | {:error, {:http_error, String.t()}}
  defp http_get_dns(url) do
    case HTTPoison.get(url, Accept: "application/dns-json") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, {:dns_error, "Failed to resolve URL over https with status code #{code}"}}

      {:error, error} ->
        error_msg =
          "Failed to resolve URL over https with request error: #{HTTPoison.Error.message(error)}"

        {:error, {:http_error, error_msg}}
    end
  end

  @spec get_ip(dns_response :: term()) :: {:ok, String.t()} | {:error, {:dns_error, String.t()}}
  defp get_ip(dns_response) do
    with %{"Answer" => answer} <- dns_response,
         %{"data" => ip} <- Enum.find(answer, &(&1["type"] == 1)) do
      {:ok, ip}
    else
      nil ->
        {:error, {:dns_error, "DNS resolution failed, no A name record found"}}

      _ ->
        {:error, {:dns_error, "DNS resolution faild to return an 'Answer'"}}
    end
  end

  @spec validate(did :: String.t(), did_document :: term()) ::
          {:ok, term()} | {:error, {:validation_error, String.t()}}
  defp validate(did, %{"id" => did} = did_document), do: {:ok, did_document}

  defp validate(did, %{"id" => id}) do
    error_msg = "DID document id (#{id}) does not match requested DID (#{did})"
    {:error, {:validation_error, error_msg}}
  end

  @spec decode_response_body(body :: term()) ::
          {:ok, term()} | {:error, {:json_error, String.t()}}
  defp decode_response_body(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, error} ->
        error_msg = "Failed to decode JSON response body: #{Jason.DecodeError.message(error)}"
        {:error, {:json_error, error_msg}}
    end
  end
end
