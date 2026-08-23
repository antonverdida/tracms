defmodule TracmsWeb.RegistrationExportController do
  use TracmsWeb, :controller

  import Phoenix.Template, only: [render_to_string: 4]

  alias Tracms.Registrations
  alias TracmsWeb.RegistrationExportHTML

  def excel(conn, params) do
    registrations = filtered_registrations(conn, params)

    conn
    |> put_root_layout(false)
    |> put_resp_content_type("application/vnd.ms-excel")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{excel_filename()}"))
    |> render(:document,
      page_title: "TRACMS Registrations Export",
      registrations: registrations,
      exported_at: DateTime.utc_now(:second),
      export_type: :excel
    )
  end

  def pdf(conn, params) do
    registrations = filtered_registrations(conn, params)

    html =
      render_to_string(RegistrationExportHTML, "document", "html",
        page_title: "TRACMS Registrations Export",
        registrations: registrations,
        exported_at: DateTime.utc_now(:second),
        export_type: :pdf
      )

    pdf_binary =
      html
      |> standalone_pdf_html()
      |> render_pdf_binary!()

    conn
    |> put_resp_content_type("application/pdf")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{pdf_filename()}"))
    |> send_resp(200, pdf_binary)
  end

  defp filtered_registrations(conn, params) do
    filters = %{
      "search" => params["search"] || "",
      "training_id" => params["training_id"] || "",
      "status" => params["status"] || ""
    }

    Registrations.list_manageable_registrations(conn.assigns.current_scope, filters)
  end

  defp excel_filename do
    "tracms-registrations-#{Date.utc_today()}.xls"
  end

  defp pdf_filename do
    "tracms-registrations-#{Date.utc_today()}.pdf"
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
  end

  defp render_pdf_binary!(html) do
    working_dir =
      Path.join(
        System.tmp_dir!(),
        "tracms-registrations-pdf-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(working_dir)

    html_path = Path.join(working_dir, "registrations.html")
    pdf_path = Path.join(working_dir, pdf_filename())
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
        raise "Chrome failed to generate registrations PDF: #{output}"
    end
  end

  defp chrome_path! do
    System.find_executable("google-chrome") ||
      System.find_executable("chromium") ||
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
    chrome_pid=$!
    wait $chrome_pid
    [ -s #{pdf} ]
    """
  end

  defp shell_escape(value) do
    "'#{String.replace(value, "'", "'\"'\"'")}'"
  end
end
