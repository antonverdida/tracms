defmodule TracmsWeb.ErrorHTMLTest do
  use TracmsWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    html = render_to_string(TracmsWeb.ErrorHTML, "404", "html", [])

    assert html =~ "Page not found"
    assert html =~ "Go to sign in"
  end

  test "renders 500.html" do
    html = render_to_string(TracmsWeb.ErrorHTML, "500", "html", [])

    assert html =~ "We could not complete that request"
    assert html =~ "Return to sign in"
  end
end
