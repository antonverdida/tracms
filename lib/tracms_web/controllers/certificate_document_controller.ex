defmodule TracmsWeb.CertificateDocumentController do
  use TracmsWeb, :controller

  import Phoenix.Template, only: [render_to_string: 4]

  alias Tracms.Certificates
  alias Tracms.Trainings
  alias TracmsWeb.CertificateDocumentHTML
  alias TracmsWeb.CertificateComponents

  def manager_print(conn, %{"training_id" => training_id, "certificate_id" => certificate_id}) do
    certificate =
      get_manager_certificate!(conn.assigns.current_scope, training_id, certificate_id)

    layout_settings = Certificates.effective_layout_settings(certificate)

    {:ok, certificate} =
      Certificates.mark_training_certificate_released(
        conn.assigns.current_scope,
        training_id,
        certificate.id
      )

    conn
    |> put_root_layout(false)
    |> render(:document,
      page_title: "#{certificate.certificate_type} Print View",
      certificate: certificate,
      layout_settings: layout_settings,
      print_page_css: certificate_print_page_css(layout_settings),
      participant_name: CertificateComponents.certificate_participant_name(certificate),
      issued_by_name: CertificateComponents.certificate_issued_by_name(certificate),
      scope_label: CertificateComponents.certificate_scope_label(certificate),
      autoprint: true,
      export_path: ~p"/certificates/trainings/#{training_id}/#{certificate.id}/export",
      back_path: ~p"/certificates?training_id=#{training_id}",
      back_label: "Back to Certificate Records"
    )
  end

  def manager_export(conn, %{"training_id" => training_id, "certificate_id" => certificate_id}) do
    certificate =
      get_manager_certificate!(conn.assigns.current_scope, training_id, certificate_id)

    {:ok, certificate} =
      Certificates.mark_training_certificate_released(
        conn.assigns.current_scope,
        training_id,
        certificate.id
      )

    pdf_binary = manager_pdf_binary!(certificate)

    conn
    |> put_resp_content_type("application/pdf")
    |> put_resp_header("content-disposition", pdf_content_disposition(certificate))
    |> send_resp(200, pdf_binary)
  end

  def manager_bulk_export(conn, %{"training_id" => training_id}) do
    training_activity =
      Trainings.get_training_activity!(conn.assigns.current_scope, training_id)

    certificates =
      Certificates.list_training_certificates(conn.assigns.current_scope, training_activity.id)

    case certificates do
      [] ->
        conn
        |> put_flash(:error, "No certificates are available for download.")
        |> redirect(to: ~p"/certificates/trainings/#{training_activity.id}")

      certificates ->
        Enum.each(certificates, fn certificate ->
          _result =
            Certificates.mark_training_certificate_released(
              conn.assigns.current_scope,
              training_activity.id,
              certificate.id
            )
        end)

        entries =
          Enum.map(certificates, fn certificate ->
            {String.to_charlist(pdf_filename(certificate)), manager_pdf_binary!(certificate)}
          end)

        archive_name = bulk_archive_filename(training_activity)

        {:ok, {_archive_name, zip_binary}} =
          :zip.create(String.to_charlist(archive_name), entries, [:memory])

        conn
        |> put_resp_content_type("application/zip")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{archive_name}"))
        |> send_resp(200, IO.iodata_to_binary(zip_binary))
    end
  end

  defp get_manager_certificate!(scope, training_id, certificate_id) do
    case Certificates.get_training_certificate(scope, training_id, certificate_id) do
      nil ->
        raise Ecto.NoResultsError, queryable: Tracms.Certificates.CertificateRecord

      certificate ->
        certificate
    end
  end

  defp pdf_content_disposition(certificate) do
    ~s(attachment; filename="#{pdf_filename(certificate)}")
  end

  defp pdf_filename(certificate) do
    "tracms-certificate-#{certificate_number_slug(certificate.certificate_number)}.pdf"
  end

  defp bulk_archive_filename(training_activity) do
    title_slug =
      training_activity.title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")

    "tracms-certificates-#{title_slug}.zip"
  end

  defp manager_document_html(certificate) do
    layout_settings = Certificates.effective_layout_settings(certificate)

    render_to_string(CertificateDocumentHTML, "document", "html",
      page_title: "#{certificate.certificate_type} Export",
      certificate: certificate,
      layout_settings: layout_settings,
      print_page_css: certificate_print_page_css(layout_settings),
      participant_name: CertificateComponents.certificate_participant_name(certificate),
      issued_by_name: CertificateComponents.certificate_issued_by_name(certificate),
      scope_label: CertificateComponents.certificate_scope_label(certificate),
      autoprint: false,
      export_path: nil,
      back_path: ~p"/certificates?training_id=#{certificate.registration.training_activity.id}",
      back_label: "Back to Certificate Records"
    )
  end

  defp manager_pdf_binary!(certificate) do
    html =
      certificate
      |> manager_document_html()
      |> standalone_pdf_html()

    working_dir =
      Path.join(
        System.tmp_dir!(),
        "tracms-certificate-pdf-#{certificate_number_slug(certificate.certificate_number)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(working_dir)

    html_path = Path.join(working_dir, "certificate.html")
    pdf_path = Path.join(working_dir, pdf_filename(certificate))
    profile_dir = Path.join(working_dir, "chrome-profile")

    File.write!(html_path, html)
    File.mkdir_p!(profile_dir)

    {output, status} =
      System.cmd(
        "/bin/sh",
        ["-c", chrome_render_script(html_path, pdf_path, profile_dir)],
        stderr_to_stdout: true
      )

    case status do
      0 ->
        pdf_binary = File.read!(pdf_path)
        File.rm_rf!(working_dir)
        pdf_binary

      _other ->
        File.rm_rf!(working_dir)
        raise "Chrome failed to generate certificate PDF: #{output}"
    end
  end

  defp standalone_pdf_html(html) do
    css =
      Application.app_dir(:tracms, "priv/static/assets/css/app.css")
      |> File.read!()

    html
    |> String.replace(
      ~r/<link rel="stylesheet" href="[^"]*\/assets\/css\/app\.css"\s*\/?>/u,
      "<style>\n#{css}\n</style>"
    )
    |> String.replace(~r/<script[^>]*src="[^"]*\/assets\/js\/app\.js"[^>]*>\s*<\/script>/u, "")
    |> localize_image_sources()
  end

  defp localize_image_sources(html) do
    Regex.replace(~r/src="(?:(?:https?:\/\/[^\/"]+))?(\/[^"]+)"/u, html, fn _match, asset_path ->
      ~s(src="file://#{Application.app_dir(:tracms, "priv/static#{asset_path}")}")
    end)
  end

  defp chrome_path! do
    System.find_executable("google-chrome") ||
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  end

  defp chrome_render_script(html_path, pdf_path, profile_dir) do
    chrome = shell_escape(chrome_path!())
    html = shell_escape("file://#{html_path}")
    pdf = shell_escape(pdf_path)
    profile = shell_escape(profile_dir)

    """
    #{chrome} \
      --headless \
      --no-sandbox \
      --disable-gpu \
      --disable-dev-shm-usage \
      --disable-background-networking \
      --disable-component-update \
      --disable-default-apps \
      --disable-sync \
      --metrics-recording-only \
      --no-first-run \
      --allow-file-access-from-files \
      --user-data-dir=#{profile} \
      --print-to-pdf=#{pdf} \
      --print-to-pdf-no-header \
      --run-all-compositor-stages-before-draw \
      --virtual-time-budget=1500 \
      #{html} >/dev/null 2>&1 &
    pid=$!
    last_size=0
    stable_count=0

    for _ in $(seq 1 80); do
      if [ -s #{pdf} ]; then
        current_size=$(wc -c < #{pdf})
        if [ "$current_size" -eq "$last_size" ] && [ "$current_size" -gt 0 ]; then
          stable_count=$((stable_count + 1))
        else
          stable_count=0
          last_size=$current_size
        fi

        if [ "$stable_count" -ge 2 ]; then
          break
        fi
      fi

      sleep 0.2
    done

    kill "$pid" >/dev/null 2>&1 || true
    wait "$pid" >/dev/null 2>&1 || true
    [ -s #{pdf} ]
    """
  end

  defp shell_escape(value) do
    "'" <> String.replace(value, "'", "'\"'\"'") <> "'"
  end

  defp certificate_number_slug(certificate_number) do
    certificate_number
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

  defp certificate_print_page_css(%{certificate_size: certificate_size}) do
    page_size =
      case certificate_size do
        "letter_landscape" -> "letter landscape"
        "legal_landscape" -> "legal landscape"
        _other -> "A4 landscape"
      end

    "@page { size: #{page_size}; margin: 0; }"
  end
end
