defmodule TracmsWeb.AttendanceExportController do
  use TracmsWeb, :controller

  import Phoenix.Template, only: [render_to_string: 4]

  alias Tracms.Attendance
  alias TracmsWeb.AttendanceExportHTML

  def excel(conn, params) do
    %{training: training_activity, entries: entries} = filtered_attendance(conn, params)

    conn
    |> put_root_layout(false)
    |> put_resp_content_type("application/vnd.ms-excel")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{excel_filename()}"))
    |> render(:document,
      page_title: "TRACMS Attendance Export",
      training_activity: training_activity,
      entries: entries,
      exported_at: DateTime.utc_now(:second),
      export_type: :excel
    )
  end

  def pdf(conn, params) do
    %{training: training_activity, entries: entries} = filtered_attendance(conn, params)

    html =
      render_to_string(AttendanceExportHTML, "document", "html",
        page_title: "TRACMS Attendance Export",
        training_activity: training_activity,
        entries: entries,
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

  defp filtered_attendance(conn, params) do
    search = params["search"] || ""

    case params["training_id"] do
      nil ->
        %{training: nil, entries: []}

      "" ->
        %{training: nil, entries: []}

      training_id ->
        case Attendance.get_training_attendance(conn.assigns.current_scope, training_id) do
          {:ok, attendance_view} ->
            %{
              training: attendance_view.training_activity,
              entries:
                Attendance.filter_training_attendance_entries(attendance_view.entries, search)
            }

          _other ->
            %{training: nil, entries: []}
        end
    end
  end

  defp excel_filename do
    "tracms-attendance-#{Date.utc_today()}.xls"
  end

  defp pdf_filename do
    "tracms-attendance-#{Date.utc_today()}.pdf"
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
        "tracms-attendance-pdf-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(working_dir)

    html_path = Path.join(working_dir, "attendance.html")
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
        raise "Chrome failed to generate attendance PDF: #{output}"
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
      --disable-setuid-sandbox \
      --no-zygote \
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
      #{html} &
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
    "'#{String.replace(value, "'", "'\"'\"'")}'"
  end
end
