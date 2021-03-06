defmodule Bamboo.SesAdapter do
  @moduledoc """
  Sends email using AWS SES API.

  Use this adapter to send emails through AWS SES API.
  """

  @behaviour Bamboo.Adapter

  alias Bamboo.SesAdapter.RFC2822WithBcc
  alias ExAws.SES
  import Bamboo.ApiError

  @doc false
  def supports_attachments?, do: true

  @doc false
  def handle_config(config) do
    config
  end

  def deliver(email, config) do
    ex_aws_config = Map.get(config, :ex_aws, [])

    case Mail.build_multipart()
         |> Mail.put_from(prepare_address(email.from))
         |> Mail.put_reply_to(email.headers["Reply-To"])
         |> Mail.put_to(prepare_addresses(email.to))
         |> Mail.put_cc(prepare_addresses(email.cc))
         |> Mail.put_bcc(prepare_addresses(email.bcc))
         |> Mail.put_subject(email.subject)
         |> put_headers(email.headers)
         |> put_text(email.text_body)
         |> put_html(email.html_body)
         |> put_attachments(email.attachments)
         |> Mail.render(RFC2822WithBcc)
         |> SES.send_raw_email()
         |> ExAws.request(ex_aws_config) do
      {:ok, response} -> response
      {:error, reason} -> raise_api_error(inspect(reason))
    end
  end

  def put_headers(email, headers) when is_map(headers), do: put_headers(email, Enum.into(headers, []))
  def put_headers(email, headers) when is_list(headers) do
    email = case Enum.at(headers, 0) do
      nil -> email
      {key, value} ->
        header_list = headers -- [{key, value}]
        headers = Map.put(email.headers, String.downcase(key), value)
        email
        |> Map.put(:headers, headers)
        |> put_headers(header_list)
    end
  end

  def put_attachments(message, []), do: message

  def put_attachments(message, attachments) do
    Enum.reduce(attachments, message, &Mail.put_attachment(&2, {&1.filename, &1.data}))
  end

  def put_text(message, nil), do: message

  def put_text(message, body), do: Mail.put_text(message, body)

  def put_html(message, nil), do: message

  def put_html(message, body), do: Mail.put_html(message, body)

  defp prepare_addresses(recipients) do
    recipients
    |> Enum.map(&prepare_address(&1))
  end

  defp prepare_address({nil, address}), do: address
  defp prepare_address({"", address}), do: address
  defp prepare_address({name, address}), do: "#{name} <#{address}>"
end
