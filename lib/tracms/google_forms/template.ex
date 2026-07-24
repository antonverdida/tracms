defmodule Tracms.GoogleForms.Template do
  @moduledoc false

  def registration_form(training_activity) do
    %{
      title: "DepEd Region IX | #{training_activity.title} | Participant Registration Form",
      document_title: "#{training_activity.title} Registration Form",
      description: registration_description(training_activity),
      email_collection_type: "RESPONDER_INPUT",
      items: [
        short_text_item("Full Name"),
        short_text_item("Employee Number"),
        short_text_item("Contact Number"),
        radio_item("Position", [
          "Teacher I",
          "Teacher II",
          "Teacher III",
          "Master Teacher",
          "School Head",
          "Education Program Supervisor",
          "Administrative Officer",
          "Other"
        ]),
        short_text_item("School or Office"),
        short_text_item("District or Division"),
        paragraph_item("Reason for Attending"),
        paragraph_item("Previous Related Training")
      ]
    }
  end

  def attendance_form(training_activity, attendance_sessions) do
    %{
      title: "DepEd Region IX | #{training_activity.title} | Attendance Monitoring Form",
      document_title: "#{training_activity.title} Attendance Form",
      description: attendance_description(training_activity, attendance_sessions),
      email_collection_type: "RESPONDER_INPUT",
      items: attendance_items(attendance_sessions)
    }
  end

  defp registration_description(training_activity) do
    """
    Official participant registration form for #{training_activity.title}.

    Schedule: #{format_date(training_activity.starts_on)} to #{format_date(training_activity.ends_on)}
    Venue: #{training_activity.venue}
    Organizer: #{training_activity.organizer}

    Please provide accurate DepEd personnel information for regional validation and certificate processing.
    """
    |> String.trim()
  end

  defp attendance_description(training_activity, attendance_sessions) do
    session_copy =
      case attendance_sessions do
        [] -> "Attendance sessions will be matched inside TRACMS after synchronization."
        _ -> "Select the correct attendance session when submitting this form."
      end

    """
    Official attendance form for #{training_activity.title}.

    Schedule: #{format_date(training_activity.starts_on)} to #{format_date(training_activity.ends_on)}
    Venue: #{training_activity.venue}

    #{session_copy}
    """
    |> String.trim()
  end

  defp attendance_items(attendance_sessions) do
    base_items = [
      short_text_item("Full Name"),
      short_text_item("Employee Number")
    ]

    session_item =
      case attendance_sessions do
        [] ->
          short_text_item("Session Name")

        sessions ->
          radio_item("Session Name", Enum.map(sessions, & &1.name))
      end

    base_items ++ [session_item, paragraph_item("Attendance Notes", false)]
  end

  defp short_text_item(title, required \\ true) do
    %{
      title: title,
      questionItem: %{
        question: %{
          required: required,
          textQuestion: %{}
        }
      }
    }
  end

  defp paragraph_item(title, required \\ true) do
    %{
      title: title,
      questionItem: %{
        question: %{
          required: required,
          textQuestion: %{paragraph: true}
        }
      }
    }
  end

  defp radio_item(title, options, required \\ true) do
    %{
      title: title,
      questionItem: %{
        question: %{
          required: required,
          choiceQuestion: %{
            type: "RADIO",
            options: Enum.map(options, &%{value: &1}),
            shuffle: false
          }
        }
      }
    }
  end

  defp format_date(nil), do: "To be announced"

  defp format_date(%Date{} = date) do
    Calendar.strftime(date, "%b %d, %Y")
  end
end
