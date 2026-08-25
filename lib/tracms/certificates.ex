defmodule Tracms.Certificates do
  @moduledoc """
  The Certificates context.
  """

  import Ecto.Query, warn: false

  alias Tracms.Accounts.Scope
  alias Tracms.Attendance.{AttendanceRecord, AttendanceSession}
  alias Tracms.Certificates.CertificateLayoutSetting
  alias Tracms.Certificates.CertificateRecord
  alias Tracms.Registrations.Registration
  alias Tracms.Repo
  alias Tracms.Trainings
  alias Tracms.Trainings.TrainingActivity

  @preloads [
    registration: [training_activity: [:office, :division], registrant_user: [:office, :role]],
    issued_by_user: []
  ]
  @layout_fields CertificateLayoutSetting.editable_fields() ++
                   CertificateLayoutSetting.asset_fields()

  def list_training_certificates(scope, training_id) do
    training_activity = Trainings.get_training_activity!(scope, training_id)

    CertificateRecord
    |> join(:inner, [certificate], registration in assoc(certificate, :registration))
    |> where(
      [_certificate, registration],
      registration.training_activity_id == ^training_activity.id
    )
    |> preload(^@preloads)
    |> order_by([certificate], desc: certificate.issued_on, desc: certificate.inserted_at)
    |> Repo.all()
  end

  def list_user_certificates(scope) do
    if scope && scope.user do
      CertificateRecord
      |> join(:inner, [certificate], registration in assoc(certificate, :registration))
      |> where([_certificate, registration], registration.registrant_user_id == ^scope.user.id)
      |> preload(^@preloads)
      |> order_by([certificate], desc: certificate.issued_on, desc: certificate.inserted_at)
      |> Repo.all()
    else
      []
    end
  end

  def list_manageable_certificates(scope) do
    if Scope.training_manager?(scope) do
      CertificateRecord
      |> join(:inner, [certificate], registration in assoc(certificate, :registration))
      |> join(
        :inner,
        [_certificate, registration],
        training in assoc(registration, :training_activity)
      )
      |> scope_manageable_certificates(scope)
      |> preload(^@preloads)
      |> order_by([certificate], desc: certificate.issued_on, desc: certificate.inserted_at)
      |> Repo.all()
    else
      []
    end
  end

  def list_certificate_trainings(scope) do
    if Scope.training_manager?(scope) do
      Trainings.list_training_activities(scope)
      |> Enum.filter(&training_completed_for_certificates?/1)
      |> Enum.sort_by(&{&1.ends_on || &1.starts_on, &1.title})
    else
      []
    end
  end

  def list_training_certificate_candidates(scope, training_id) do
    training_activity = Trainings.get_training_activity!(scope, training_id)
    registrations = list_training_registrations(training_activity.id)
    registration_ids = Enum.map(registrations, & &1.id)
    attendance_by_registration_id = latest_training_attendance_map(training_activity.id)
    certificates_by_registration_id = list_certificate_map_for_registrations(registration_ids)

    Enum.map(registrations, fn registration ->
      attendance_record = Map.get(attendance_by_registration_id, registration.id)
      certificate = Map.get(certificates_by_registration_id, registration.id)
      eligible? = certificate_eligible?(training_activity, registration, attendance_record)

      %{
        registration: registration,
        attendance_record: attendance_record,
        certificate: certificate,
        eligible?: eligible?,
        certificate_status: certificate_status_label(certificate)
      }
    end)
  end

  def list_certificate_map_for_registrations([]), do: %{}

  def list_certificate_map_for_registrations(registration_ids) do
    CertificateRecord
    |> where([certificate], certificate.registration_id in ^registration_ids)
    |> preload(^@preloads)
    |> Repo.all()
    |> Map.new(&{&1.registration_id, &1})
  end

  def get_user_certificate(scope, certificate_id) do
    if scope && scope.user do
      CertificateRecord
      |> join(:inner, [certificate], registration in assoc(certificate, :registration))
      |> where(
        [certificate, registration],
        certificate.id == ^certificate_id and registration.registrant_user_id == ^scope.user.id
      )
      |> preload(^@preloads)
      |> Repo.one()
    end
  end

  def get_training_certificate(scope, training_id, certificate_id) do
    training_activity = Trainings.get_training_activity!(scope, training_id)

    CertificateRecord
    |> join(:inner, [certificate], registration in assoc(certificate, :registration))
    |> where(
      [certificate, registration],
      certificate.id == ^certificate_id and
        registration.training_activity_id == ^training_activity.id
    )
    |> preload(^@preloads)
    |> Repo.one()
  end

  def get_certificate_by_number(certificate_number) when is_binary(certificate_number) do
    certificate_number
    |> String.trim()
    |> case do
      "" ->
        nil

      normalized_number ->
        CertificateRecord
        |> where([certificate], certificate.certificate_number == ^normalized_number)
        |> preload(^@preloads)
        |> Repo.one()
    end
  end

  def get_certificate_by_number(_certificate_number), do: nil

  def verify_certificate_by_number(certificate_number) do
    certificate_number
    |> get_certificate_by_number()
    |> verification_result()
  end

  def verify_certificate_by_code(verification_code) when is_binary(verification_code) do
    verification_code
    |> String.trim()
    |> case do
      "" ->
        nil

      normalized_code ->
        CertificateRecord
        |> where([certificate], certificate.verification_code == ^normalized_code)
        |> preload(^@preloads)
        |> Repo.one()
    end
    |> verification_result()
  end

  def verify_certificate_by_code(_verification_code), do: {:invalid, :not_found}

  def list_issueable_entries(scope, training_id) do
    scope
    |> list_training_certificate_candidates(training_id)
    |> Enum.filter(&(&1.eligible? and is_nil(&1.certificate)))
  end

  def issue_certificate(scope, registration_id) do
    with true <- Scope.training_manager?(scope),
         %Registration{} = registration <- get_registration_for_issuance(registration_id),
         true <- manageable_registration?(scope, registration),
         true <- certificate_eligible_for_issuance?(registration),
         nil <- get_certificate_for_registration(registration.id),
         {:ok, certificate_number} <- next_certificate_number() do
      %CertificateRecord{}
      |> CertificateRecord.changeset(%{
        registration_id: registration.id,
        issued_by_user_id: scope.user.id,
        certificate_number: certificate_number,
        verification_code: generate_verification_code(),
        verification_status: :active,
        certificate_type: registration.training_activity.certificate_type,
        issued_on: Date.utc_today(),
        delivery_status: :available
      })
      |> Repo.insert()
      |> preload_result()
    else
      false -> {:error, :unauthorized}
      nil -> {:error, :registration_not_found}
      %CertificateRecord{} -> {:error, :already_issued}
      :not_eligible -> {:error, :not_eligible}
      :certificate_number_range_exhausted -> {:error, :certificate_number_range_exhausted}
    end
  end

  def issue_certificates_for_training(scope, training_id) do
    scope
    |> list_issueable_entries(training_id)
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, certificates} ->
      case issue_certificate(scope, entry.registration.id) do
        {:ok, certificate} ->
          {:cont, {:ok, [certificate | certificates]}}

        {:error, :already_issued} ->
          {:cont, {:ok, certificates}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, certificates} ->
        {:ok, Enum.reverse(certificates)}

      other ->
        other
    end
  end

  def issue_manual_certificates_for_training(scope, training_id) do
    scope
    |> list_training_certificate_candidates(training_id)
    |> Enum.filter(fn entry ->
      manual_participant?(entry.registration) and is_nil(entry.certificate)
    end)
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, certificates} ->
      case issue_certificate(scope, entry.registration.id) do
        {:ok, certificate} ->
          {:cont, {:ok, [certificate | certificates]}}

        {:error, :already_issued} ->
          {:cont, {:ok, certificates}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, certificates} -> {:ok, Enum.reverse(certificates)}
      other -> other
    end
  end

  def regenerate_training_certificate(scope, training_id, certificate_id) do
    case get_training_certificate(scope, training_id, certificate_id) do
      nil ->
        {:error, :not_found}

      certificate ->
        certificate
        |> CertificateRecord.changeset(%{
          issued_on: Date.utc_today(),
          certificate_type: certificate.registration.training_activity.certificate_type,
          delivery_status: :available,
          downloaded_at: nil,
          emailed_at: nil
        })
        |> Repo.update()
        |> preload_result()
    end
  end

  def mark_training_certificate_released(scope, training_id, certificate_id) do
    case get_training_certificate(scope, training_id, certificate_id) do
      nil ->
        {:error, :not_found}

      certificate ->
        certificate
        |> CertificateRecord.changeset(%{
          delivery_status: :downloaded,
          downloaded_at: DateTime.utc_now(:second)
        })
        |> Repo.update()
        |> preload_result()
    end
  end

  def mark_training_certificate_emailed(scope, training_id, certificate_id) do
    case get_training_certificate(scope, training_id, certificate_id) do
      nil ->
        {:error, :not_found}

      certificate ->
        certificate
        |> CertificateRecord.changeset(%{
          delivery_status: :emailed,
          emailed_at: DateTime.utc_now(:second)
        })
        |> Repo.update()
        |> preload_result()
    end
  end

  def mark_downloaded(scope, certificate_id) do
    case get_user_certificate(scope, certificate_id) do
      nil ->
        {:error, :not_found}

      certificate ->
        certificate
        |> CertificateRecord.changeset(%{
          delivery_status: :downloaded,
          downloaded_at: DateTime.utc_now(:second)
        })
        |> Repo.update()
        |> preload_result()
    end
  end

  def acknowledge_certificate_access(scope, certificate_id) do
    case get_user_certificate(scope, certificate_id) do
      nil ->
        {:error, :not_found}

      %{delivery_status: :downloaded} = certificate ->
        {:ok, certificate}

      _certificate ->
        mark_downloaded(scope, certificate_id)
    end
  end

  def get_certificate_for_registration(registration_id) do
    CertificateRecord
    |> Repo.get_by(registration_id: registration_id)
    |> maybe_preload_certificate()
  end

  def certificate_layout_style_options do
    CertificateLayoutSetting.layout_style_options()
  end

  def certificate_size_options do
    CertificateLayoutSetting.certificate_size_options()
  end

  def certificate_accent_color_options do
    CertificateLayoutSetting.accent_color_options()
  end

  def get_default_certificate_layout_setting do
    Repo.get_by(CertificateLayoutSetting, scope_key: "default") ||
      struct(CertificateLayoutSetting, CertificateLayoutSetting.defaults())
  end

  def change_default_certificate_layout(attrs \\ %{}) do
    get_default_certificate_layout_setting()
    |> CertificateLayoutSetting.changeset(attrs)
  end

  def update_default_certificate_layout(scope, attrs) do
    if Scope.system_admin?(scope) do
      layout_setting = get_default_certificate_layout_setting()
      changeset = CertificateLayoutSetting.changeset(layout_setting, attrs)

      case layout_setting.id do
        nil -> Repo.insert(changeset)
        _id -> Repo.update(changeset)
      end
    else
      {:error, :unauthorized}
    end
  end

  def default_certificate_layout do
    default_certificate_layout(get_default_certificate_layout_setting())
  end

  def default_certificate_layout(%CertificateLayoutSetting{} = layout_setting) do
    CertificateLayoutSetting.defaults()
    |> Map.take(@layout_fields)
    |> Map.merge(layout_value_map(layout_setting))
  end

  def effective_layout_settings(%TrainingActivity{} = training_activity) do
    Map.merge(default_certificate_layout(), training_layout_overrides(training_activity))
  end

  def effective_layout_settings(%CertificateRecord{
        registration: %{training_activity: %TrainingActivity{} = training_activity}
      }) do
    effective_layout_settings(training_activity)
  end

  def effective_layout_settings(%{
        registration: %{training_activity: %TrainingActivity{} = training_activity}
      }) do
    effective_layout_settings(training_activity)
  end

  def effective_layout_settings(_data) do
    default_certificate_layout()
  end

  def custom_layout_override?(%TrainingActivity{} = training_activity) do
    training_layout_overrides(training_activity) != %{}
  end

  def sample_preview_certificate do
    sample_preview_certificate(nil)
  end

  def sample_preview_certificate(%TrainingActivity{} = training_activity) do
    today = Date.utc_today()
    starts_on = training_activity.starts_on || Date.add(today, 14)
    ends_on = training_activity.ends_on || Date.add(starts_on, 2)

    %{
      certificate_number: "000001",
      certificate_type: training_activity.certificate_type || "Certificate of Completion",
      issued_on: today,
      delivery_status: :available,
      registration: %{
        training_activity: %{
          title: training_activity.title || "Regional Learning and Development Program",
          starts_on: starts_on,
          ends_on: ends_on,
          office: training_activity.office || %{name: "DepEd Region IX"},
          division: training_activity.division
        },
        registrant_user: %{
          full_name: "Juan Dela Cruz",
          email: "juan.delacruz@deped.gov.ph"
        }
      },
      issued_by_user: %{
        full_name: "TRACMS Administrator",
        email: "admin@tracms.local"
      }
    }
  end

  def sample_preview_certificate(nil) do
    today = Date.utc_today()

    %{
      certificate_number: "000001",
      certificate_type: "Certificate of Completion",
      issued_on: today,
      delivery_status: :available,
      registration: %{
        training_activity: %{
          title: "Regional Training Management Orientation",
          starts_on: Date.add(today, 14),
          ends_on: Date.add(today, 16),
          office: %{name: "DepEd Region IX Training Office"},
          division: nil
        },
        registrant_user: %{
          full_name: "Juan Dela Cruz",
          email: "juan.delacruz@deped.gov.ph"
        }
      },
      issued_by_user: %{
        full_name: "TRACMS Administrator",
        email: "admin@tracms.local"
      }
    }
  end

  def format_delivery_status(status) when is_atom(status) do
    certificate_status_label(%CertificateRecord{delivery_status: status})
  end

  def certificate_status_label(nil), do: "Not Generated"
  def certificate_status_label(%CertificateRecord{delivery_status: :available}), do: "Generated"
  def certificate_status_label(%CertificateRecord{}), do: "Released"

  defp verification_result(%CertificateRecord{verification_status: :active} = certificate),
    do: {:valid, certificate}

  defp verification_result(%CertificateRecord{}), do: {:invalid, :revoked}
  defp verification_result(nil), do: {:invalid, :not_found}

  defp generate_verification_code do
    :crypto.strong_rand_bytes(24)
    |> Base.url_encode64(padding: false)
  end

  defp get_registration_for_issuance(registration_id) do
    Registration
    |> preload(training_activity: [:office, :division], registrant_user: [:office, :role])
    |> Repo.get(registration_id)
  end

  defp certificate_eligible_for_issuance?(registration) do
    (training_completed_for_certificates?(registration.training_activity) and
       (manual_participant?(registration) ||
          latest_registration_attendance_status(
            registration.training_activity_id,
            registration.id
          ) ==
            :present)) ||
      :not_eligible
  end

  defp manageable_registration?(scope, registration) do
    training_activity =
      if Ecto.assoc_loaded?(registration.training_activity) do
        registration.training_activity
      else
        Repo.get(TrainingActivity, registration.training_activity_id)
      end

    cond do
      Scope.regional_admin?(scope) ->
        true

      Scope.division_admin?(scope) ->
        scope.division_id && training_activity.division_id == scope.division_id

      Scope.coordinator?(scope) ->
        scope.office_id && training_activity.office_id == scope.office_id

      true ->
        false
    end
  end

  defp scope_manageable_certificates(query, scope) do
    cond do
      Scope.regional_admin?(scope) ->
        query

      Scope.division_admin?(scope) and scope.division_id ->
        where(
          query,
          [_certificate, _registration, training],
          training.division_id == ^scope.division_id
        )

      Scope.coordinator?(scope) and scope.office_id ->
        where(
          query,
          [_certificate, _registration, training],
          training.office_id == ^scope.office_id
        )

      true ->
        where(query, [_certificate, _registration, _training], false)
    end
  end

  defp list_training_registrations(training_id) do
    Registration
    |> where(
      [registration],
      registration.training_activity_id == ^training_id and
        registration.status == :approved
    )
    |> preload([:training_activity, registrant_user: [:office, :role]])
    |> order_by([registration], asc: registration.inserted_at)
    |> Repo.all()
  end

  defp latest_training_attendance_map(training_id) do
    session_ids =
      AttendanceSession
      |> where([session], session.training_activity_id == ^training_id)
      |> select([session], session.id)
      |> Repo.all()

    if session_ids == [] do
      %{}
    else
      AttendanceRecord
      |> where([record], record.attendance_session_id in ^session_ids)
      |> order_by([record], desc: record.marked_at, desc: record.inserted_at)
      |> Repo.all()
      |> Enum.reduce(%{}, fn record, acc ->
        Map.put_new(acc, record.registration_id, record)
      end)
    end
  end

  defp latest_registration_attendance_status(training_id, registration_id) do
    training_id
    |> latest_training_attendance_map()
    |> Map.get(registration_id)
    |> case do
      %AttendanceRecord{status: status} -> status
      nil -> nil
    end
  end

  defp certificate_eligible?(training_activity, registration, attendance_record) do
    training_completed_for_certificates?(training_activity) and
      (manual_participant?(registration) ||
         match?(%AttendanceRecord{status: :present}, attendance_record))
  end

  defp manual_participant?(%Registration{manual_participant_name: name}) when is_binary(name) do
    String.trim(name) != ""
  end

  defp manual_participant?(_registration), do: false

  defp training_completed_for_certificates?(%TrainingActivity{status: status}) do
    status in [:completed, :archived]
  end

  defp next_certificate_number do
    issued_serials =
      CertificateRecord
      |> select([certificate], certificate.certificate_number)
      |> Repo.all()
      |> MapSet.new(&certificate_serial/1)

    next_serial = (issued_serials |> Enum.reject(&is_nil/1) |> Enum.max(fn -> 0 end)) + 1

    {:ok, Integer.to_string(next_serial) |> String.pad_leading(6, "0")}
  end

  defp certificate_serial(certificate_number) when is_binary(certificate_number),
    do: parse_serial(certificate_number)

  defp certificate_serial(_certificate_number), do: nil

  defp parse_serial(certificate_number) do
    case Integer.parse(certificate_number) do
      {serial, ""} -> serial
      _other -> nil
    end
  end

  defp maybe_preload_certificate(nil), do: nil
  defp maybe_preload_certificate(certificate), do: Repo.preload(certificate, @preloads)

  defp preload_result({:ok, certificate}), do: {:ok, Repo.preload(certificate, @preloads)}
  defp preload_result(other), do: other

  defp training_layout_overrides(training_activity) do
    %{
      layout_style: training_activity.certificate_layout_style,
      accent_color: training_activity.certificate_accent_color,
      header_title: training_activity.certificate_header_title,
      header_subtitle: training_activity.certificate_header_subtitle,
      body_intro: training_activity.certificate_body_intro,
      completion_statement: training_activity.certificate_completion_statement,
      signature_label: training_activity.certificate_signature_label,
      issuing_office_label: training_activity.certificate_issuing_office_label
    }
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end

  defp layout_value_map(layout_setting) do
    layout_setting
    |> Map.take(@layout_fields)
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end
end
