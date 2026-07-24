defmodule Tracms.Certificates do
  @moduledoc """
  The Certificates context.
  """

  import Ecto.Query, warn: false

  alias Tracms.Accounts.Scope
  alias Tracms.Certificates.CertificateRecord
  alias Tracms.Evaluations
  alias Tracms.Registrations.Registration
  alias Tracms.Repo
  alias Tracms.Trainings
  alias Tracms.Trainings.TrainingActivity

  @preloads [
    registration: [training_activity: [:office, :division], registrant_user: [:office, :role]],
    issued_by_user: []
  ]

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

  def list_issueable_entries(scope, training_id) do
    entries = Evaluations.list_training_completion(scope, training_id)
    registration_ids = Enum.map(entries, & &1.registration.id)

    issued_registration_ids =
      if registration_ids == [] do
        MapSet.new()
      else
        CertificateRecord
        |> where([certificate], certificate.registration_id in ^registration_ids)
        |> select([certificate], certificate.registration_id)
        |> Repo.all()
        |> MapSet.new()
      end

    Enum.filter(entries, fn entry ->
      entry.completion_status == :completed and
        not MapSet.member?(issued_registration_ids, entry.registration.id)
    end)
  end

  def issue_certificate(scope, registration_id) do
    with true <- Scope.training_manager?(scope),
         %Registration{} = registration <- get_registration_for_issuance(registration_id),
         true <- manageable_registration?(scope, registration),
         true <- completion_ready?(scope, registration),
         nil <- get_certificate_for_registration(registration.id) do
      %CertificateRecord{}
      |> CertificateRecord.changeset(%{
        registration_id: registration.id,
        issued_by_user_id: scope.user.id,
        certificate_number: next_certificate_number(),
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

  def format_delivery_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp get_registration_for_issuance(registration_id) do
    Registration
    |> preload(training_activity: [:office, :division], registrant_user: [:office, :role])
    |> Repo.get(registration_id)
  end

  defp completion_ready?(scope, registration) do
    Evaluations.list_training_completion(scope, registration.training_activity_id)
    |> Enum.find(fn entry -> entry.registration.id == registration.id end)
    |> case do
      %{completion_status: :completed} -> true
      _ -> false
    end
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

  defp next_certificate_number do
    year = Date.utc_today().year

    candidate =
      "DEPED9-#{year}-#{System.unique_integer([:positive]) |> Integer.to_string() |> String.pad_leading(6, "0")}"

    if Repo.get_by(CertificateRecord, certificate_number: candidate) do
      next_certificate_number()
    else
      candidate
    end
  end

  defp maybe_preload_certificate(nil), do: nil
  defp maybe_preload_certificate(certificate), do: Repo.preload(certificate, @preloads)

  defp preload_result({:ok, certificate}), do: {:ok, Repo.preload(certificate, @preloads)}
  defp preload_result(other), do: other
end
