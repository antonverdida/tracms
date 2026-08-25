alias Tracms.Accounts.{Role, User}
alias Tracms.Attendance.{AttendanceRecord, AttendanceSession}
alias Tracms.Certificates.CertificateRecord
alias Tracms.Evaluations.EvaluationSubmission
alias Tracms.Organization.{Division, Office}
alias Tracms.Repo
alias Tracms.Registrations.Registration
alias Tracms.Trainings.{TrainingActivity, TrainingApproval}

roles = [
  %{
    key: "regional_admin",
    name: "Regional Administrator",
    description: "Full regional oversight for TRACMS.",
    scope: :region
  },
  %{
    key: "division_admin",
    name: "Division Administrator",
    description: "Division-level administrative management and reporting.",
    scope: :division
  },
  %{
    key: "training_coordinator",
    name: "Training Coordinator",
    description: "Manages training activities, attendance, and certificates.",
    scope: :office
  },
  %{
    key: "participant",
    name: "Participant",
    description: "Registers for training and accesses issued certificates.",
    scope: :participant
  }
]

Enum.each(roles, fn role_attrs ->
  %Role{}
  |> Role.changeset(role_attrs)
  |> Repo.insert!(
    on_conflict: [
      set: [
        name: role_attrs.name,
        description: role_attrs.description,
        scope: Atom.to_string(role_attrs.scope),
        is_assignable: true,
        updated_at: DateTime.utc_now(:second)
      ]
    ],
    conflict_target: :key
  )
end)

divisions = [
  %{code: "RO9", name: "DepEd Region IX Regional Office"},
  %{code: "ZDN", name: "Schools Division of Zamboanga del Norte"},
  %{code: "ZDS", name: "Schools Division of Zamboanga del Sur"},
  %{code: "ZSP", name: "Schools Division of Zamboanga Sibugay"},
  %{code: "ZC", name: "Schools Division of Zamboanga City"},
  %{code: "ISABELA", name: "Schools Division of Isabela City"},
  %{code: "DAPITAN", name: "Schools Division of Dapitan City"},
  %{code: "DIPOLOG", name: "Schools Division of Dipolog City"},
  %{code: "PAGADIAN", name: "Schools Division of Pagadian City"}
]

division_ids =
  Enum.reduce(divisions, %{}, fn division_attrs, acc ->
    division =
      %Division{}
      |> Division.changeset(division_attrs)
      |> Repo.insert!(
        on_conflict: [
          set: [
            name: division_attrs.name,
            region: "Region IX",
            is_active: true,
            updated_at: DateTime.utc_now(:second)
          ]
        ],
        conflict_target: :code,
        returning: true
      )

    Map.put(acc, division_attrs.code, division.id)
  end)

offices = [
  %{
    code: "RO9-REG",
    name: "DepEd Region IX Regional Office",
    level: :regional,
    division_code: "RO9"
  },
  %{
    code: "RO9-ZDN",
    name: "Schools Division of Zamboanga del Norte",
    level: :division,
    division_code: "ZDN"
  },
  %{
    code: "RO9-ZDS",
    name: "Schools Division of Zamboanga del Sur",
    level: :division,
    division_code: "ZDS"
  },
  %{
    code: "RO9-ZSP",
    name: "Schools Division of Zamboanga Sibugay",
    level: :division,
    division_code: "ZSP"
  },
  %{
    code: "RO9-ZC",
    name: "Schools Division of Zamboanga City",
    level: :division,
    division_code: "ZC"
  },
  %{
    code: "RO9-ISA",
    name: "Schools Division of Isabela City",
    level: :division,
    division_code: "ISABELA"
  },
  %{
    code: "RO9-DAP",
    name: "Schools Division of Dapitan City",
    level: :division,
    division_code: "DAPITAN"
  },
  %{
    code: "RO9-DIP",
    name: "Schools Division of Dipolog City",
    level: :division,
    division_code: "DIPOLOG"
  },
  %{
    code: "RO9-PAG",
    name: "Schools Division of Pagadian City",
    level: :division,
    division_code: "PAGADIAN"
  }
]

Enum.each(offices, fn office_attrs ->
  attrs = %{
    code: office_attrs.code,
    name: office_attrs.name,
    level: office_attrs.level,
    division_id: Map.fetch!(division_ids, office_attrs.division_code)
  }

  %Office{}
  |> Office.changeset(attrs)
  |> Repo.insert!(
    on_conflict: [
      set: [
        name: office_attrs.name,
        level: Atom.to_string(office_attrs.level),
        division_id: Map.fetch!(division_ids, office_attrs.division_code),
        is_active: true,
        updated_at: DateTime.utc_now(:second)
      ]
    ],
    conflict_target: :code
  )
end)

demo_email = "admin@tracms.local"
demo_password = "Admin123456!"

regional_admin_role = Repo.get_by!(Role, key: "regional_admin")
regional_office = Repo.get_by!(Office, code: "RO9-REG")

demo_user =
  Repo.get_by(User, email: demo_email) ||
    %User{}
    |> User.registration_changeset(%{email: demo_email, username: "admin"})
    |> Repo.insert!()

demo_user
|> User.profile_changeset(%{
  full_name: "TRACMS Administrator",
  status: :active,
  role_id: regional_admin_role.id,
  office_id: regional_office.id,
  approved_at: DateTime.utc_now(:second)
})
|> User.password_changeset(%{password: demo_password})
|> Ecto.Changeset.change(confirmed_at: DateTime.utc_now(:second))
|> Repo.update!()

division_admin_role = Repo.get_by!(Role, key: "division_admin")
coordinator_role = Repo.get_by!(Role, key: "training_coordinator")
participant_role = Repo.get_by!(Role, key: "participant")

zds_office = Repo.get_by!(Office, code: "RO9-ZDS")
pagadian_office = Repo.get_by!(Office, code: "RO9-PAG")
zamboanga_city_office = Repo.get_by!(Office, code: "RO9-ZC")
zdn_office = Repo.get_by!(Office, code: "RO9-ZDN")

demo_password = "Admin123456!"

ensure_user = fn email, attrs ->
  user =
    Repo.get_by(User, email: email) ||
      %User{}
      |> User.registration_changeset(%{email: email, username: email |> String.split("@") |> hd()})
      |> Repo.insert!()

  user
  |> User.profile_changeset(
    attrs
    |> Map.put(:status, :active)
    |> Map.put(:approved_at, DateTime.utc_now(:second))
  )
  |> User.password_changeset(%{password: demo_password})
  |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now(:second))
  |> Repo.update!()
end

_division_admin_user =
  ensure_user.("division.admin@tracms.local", %{
    full_name: "Zamboanga del Sur Division Admin",
    employee_number: "DIV-2026-001",
    role_id: division_admin_role.id,
    office_id: zds_office.id
  })

coordinator_user =
  ensure_user.("coordinator@tracms.local", %{
    full_name: "Pagadian Training Coordinator",
    employee_number: "COORD-2026-001",
    role_id: coordinator_role.id,
    office_id: pagadian_office.id
  })

participant_users =
  [
    %{
      email: "juan.cruz@deped.gov.ph",
      full_name: "Juan Cruz",
      employee_number: "P-2026-001",
      office_id: pagadian_office.id
    },
    %{
      email: "maria.santos@deped.gov.ph",
      full_name: "Maria Santos",
      employee_number: "P-2026-002",
      office_id: zamboanga_city_office.id
    },
    %{
      email: "ana.reyes@deped.gov.ph",
      full_name: "Ana Reyes",
      employee_number: "P-2026-003",
      office_id: zds_office.id
    },
    %{
      email: "pedro.garcia@deped.gov.ph",
      full_name: "Pedro Garcia",
      employee_number: "P-2026-004",
      office_id: zdn_office.id
    }
  ]
  |> Enum.map(fn participant_attrs ->
    ensure_user.(participant_attrs.email, %{
      full_name: participant_attrs.full_name,
      employee_number: participant_attrs.employee_number,
      role_id: participant_role.id,
      office_id: participant_attrs.office_id
    })
  end)

ensure_training = fn attrs ->
  case Repo.get_by(TrainingActivity, title: attrs.title) do
    nil ->
      %TrainingActivity{}
      |> TrainingActivity.changeset(attrs)
      |> Repo.insert!()

    %TrainingActivity{} = training_activity ->
      training_activity
      |> TrainingActivity.changeset(attrs)
      |> Repo.update!()
  end
end

ensure_training_approval = fn attrs ->
  case Repo.get_by(TrainingApproval,
         training_activity_id: attrs.training_activity_id,
         action: attrs.action,
         to_status: attrs.to_status
       ) do
    nil ->
      %TrainingApproval{}
      |> TrainingApproval.changeset(attrs)
      |> Repo.insert!()

    %TrainingApproval{} = approval ->
      approval
      |> TrainingApproval.changeset(attrs)
      |> Repo.update!()
  end
end

digital_education_trends =
  ensure_training.(%{
    title: "Digital Education Trends",
    description:
      "Regional capability-building activity focused on emerging digital teaching strategies, AI-assisted classroom planning, and ICT policy alignment.",
    objectives:
      "Strengthen teacher readiness in digital instruction, establish responsible AI classroom practices, and align school implementation planning across Region IX.",
    category: "Information and Communication Technology",
    training_type: "Capacity Building Training",
    organizer: "Human Resource Development Division",
    modality: :hybrid,
    venue: "DepEd Regional Office IX Training Center",
    venue_address: "Pagadian City, Zamboanga del Sur",
    status: :published,
    registration_opens_on: ~D[2026-07-20],
    registration_deadline: ~U[2026-08-05 09:00:00Z],
    max_capacity: 150,
    starts_on: ~D[2026-08-10],
    ends_on: ~D[2026-08-12],
    total_hours: 24,
    target_participants: "Teachers, ICT coordinators, and school heads",
    participant_qualification: "Must be endorsed by the school head or division office.",
    attendance_monitoring_method: "QR Code and Manual Verification",
    certificate_type: "Certificate of Participation",
    minimum_attendance_percentage: 75,
    evaluation_required: true,
    published_at: ~U[2026-07-22 08:00:00Z],
    registration_form_id: "seed-registration-form-digital-education-trends",
    registration_form_url:
      "https://docs.google.com/forms/d/seed-registration-form-digital-education-trends/viewform",
    attendance_form_id: "seed-attendance-form-digital-education-trends",
    attendance_form_url:
      "https://docs.google.com/forms/d/seed-attendance-form-digital-education-trends/viewform",
    registration_sheet_id: "seed-registration-sheet-digital-education-trends",
    registration_sheet_range: "Form Responses 1!A:F",
    attendance_sheet_id: "seed-attendance-sheet-digital-education-trends",
    attendance_sheet_range: "Attendance!A:C",
    creator_user_id: coordinator_user.id,
    office_id: pagadian_office.id,
    division_id: pagadian_office.division_id
  })

instructional_coaching_program =
  ensure_training.(%{
    title: "Instructional Coaching Program",
    description:
      "An ongoing training delivery track for school-based instructional coaching and observation practices.",
    objectives:
      "Support teacher mentors and school heads in observation, coaching cycles, and professional learning community facilitation.",
    category: "Teacher Development",
    training_type: "Professional Development Program",
    organizer: "DepEd Region IX",
    modality: :face_to_face,
    venue: "Pagadian City Division Hall",
    venue_address: "Pagadian City, Zamboanga del Sur",
    status: :in_progress,
    registration_opens_on: ~D[2026-06-20],
    registration_deadline: ~U[2026-07-15 17:00:00Z],
    max_capacity: 80,
    starts_on: ~D[2026-07-23],
    ends_on: ~D[2026-07-25],
    total_hours: 18,
    target_participants: "Master Teachers, school heads, and instructional leaders",
    participant_qualification: "Must be assigned to teacher support or school leadership duties.",
    attendance_monitoring_method: "Manual Verification",
    certificate_type: "Certificate of Completion",
    minimum_attendance_percentage: 80,
    evaluation_required: true,
    published_at: ~U[2026-07-10 08:00:00Z],
    attendance_form_id: "seed-attendance-form-instructional-coaching",
    attendance_form_url:
      "https://docs.google.com/forms/d/seed-attendance-form-instructional-coaching/viewform",
    attendance_sheet_id: "seed-attendance-sheet-instructional-coaching",
    attendance_sheet_range: "Attendance!A:C",
    creator_user_id: coordinator_user.id,
    office_id: pagadian_office.id,
    division_id: pagadian_office.division_id
  })

learning_recovery_bootcamp =
  ensure_training.(%{
    title: "Learning Recovery and Acceleration Program",
    description:
      "Completed regional intervention program on learning recovery strategies, remediation planning, and classroom monitoring.",
    objectives:
      "Equip teachers with recovery planning tools, differentiated remediation strategies, and measurement approaches for learning gaps.",
    category: "Curriculum and Instruction",
    training_type: "Orientation and Workshop",
    organizer: "DepEd Region IX",
    modality: :face_to_face,
    venue: "Regional Learning Center",
    venue_address: "Pagadian City, Zamboanga del Sur",
    status: :completed,
    registration_opens_on: ~D[2026-06-01],
    registration_deadline: ~U[2026-06-20 17:00:00Z],
    max_capacity: 60,
    starts_on: ~D[2026-07-01],
    ends_on: ~D[2026-07-03],
    total_hours: 24,
    target_participants: "Elementary and secondary teachers handling remediation programs",
    participant_qualification: "Must be assigned to reading or numeracy recovery initiatives.",
    attendance_monitoring_method: "QR Code and Manual Verification",
    certificate_type: "Certificate of Completion",
    minimum_attendance_percentage: 80,
    evaluation_required: true,
    published_at: ~U[2026-06-15 08:00:00Z],
    creator_user_id: coordinator_user.id,
    office_id: pagadian_office.id,
    division_id: pagadian_office.division_id
  })

regional_ict_planning_workshop =
  ensure_training.(%{
    title: "Regional ICT Planning Workshop",
    description:
      "Draft planning workshop for division ICT roadmap alignment and annual equipment utilization review.",
    objectives:
      "Prepare division-level ICT implementation plans and consolidate digital infrastructure priorities.",
    category: "Governance and Administration",
    training_type: "Technical Assistance",
    organizer: "DepEd Region IX",
    modality: :hybrid,
    venue: "Regional Conference Hall",
    venue_address: "Pagadian City, Zamboanga del Sur",
    status: :draft,
    registration_opens_on: ~D[2026-08-15],
    registration_deadline: ~U[2026-08-30 17:00:00Z],
    max_capacity: 45,
    starts_on: ~D[2026-09-10],
    ends_on: ~D[2026-09-11],
    total_hours: 12,
    target_participants: "Division ICT coordinators and planning officers",
    participant_qualification: "Must be endorsed by the division superintendent.",
    attendance_monitoring_method: "Manual Verification",
    certificate_type: "Certificate of Participation",
    minimum_attendance_percentage: 75,
    evaluation_required: false,
    creator_user_id: coordinator_user.id,
    office_id: pagadian_office.id,
    division_id: pagadian_office.division_id
  })

Enum.each(
  [
    %{
      training_activity_id: digital_education_trends.id,
      action: :created,
      actor_role_key: "training_coordinator",
      from_status: nil,
      to_status: :published,
      acted_by_user_id: coordinator_user.id
    },
    %{
      training_activity_id: instructional_coaching_program.id,
      action: :created,
      actor_role_key: "training_coordinator",
      from_status: nil,
      to_status: :in_progress,
      acted_by_user_id: coordinator_user.id
    },
    %{
      training_activity_id: learning_recovery_bootcamp.id,
      action: :created,
      actor_role_key: "training_coordinator",
      from_status: nil,
      to_status: :completed,
      acted_by_user_id: coordinator_user.id
    },
    %{
      training_activity_id: regional_ict_planning_workshop.id,
      action: :created,
      actor_role_key: "training_coordinator",
      from_status: nil,
      to_status: :draft,
      acted_by_user_id: coordinator_user.id
    }
  ],
  ensure_training_approval
)

ensure_registration = fn attrs ->
  case Repo.get_by(Registration,
         training_activity_id: attrs.training_activity_id,
         registrant_user_id: attrs.registrant_user_id
       ) do
    nil ->
      %Registration{}
      |> Registration.changeset(attrs)
      |> Repo.insert!()

    %Registration{} = registration ->
      registration
      |> Registration.changeset(attrs)
      |> Repo.update!()
  end
end

future_registrations = [
  %{
    training_activity_id: digital_education_trends.id,
    registrant_user_id: Enum.at(participant_users, 0).id,
    reviewer_user_id: coordinator_user.id,
    status: :approved,
    submitted_at: ~U[2026-07-22 09:00:00Z],
    reviewed_at: ~U[2026-07-23 09:00:00Z],
    special_requirements: "Needs printed session materials."
  },
  %{
    training_activity_id: digital_education_trends.id,
    registrant_user_id: Enum.at(participant_users, 1).id,
    status: :submitted,
    submitted_at: ~U[2026-07-23 11:00:00Z]
  },
  %{
    training_activity_id: digital_education_trends.id,
    registrant_user_id: Enum.at(participant_users, 2).id,
    reviewer_user_id: coordinator_user.id,
    status: :waitlisted,
    submitted_at: ~U[2026-07-21 14:30:00Z],
    reviewed_at: ~U[2026-07-23 13:30:00Z],
    review_notes: "Waitlisted due to office allocation limit."
  },
  %{
    training_activity_id: digital_education_trends.id,
    registrant_user_id: Enum.at(participant_users, 3).id,
    reviewer_user_id: coordinator_user.id,
    status: :rejected,
    submitted_at: ~U[2026-07-21 08:15:00Z],
    reviewed_at: ~U[2026-07-22 10:15:00Z],
    review_notes: "Endorsement document not yet provided."
  }
]

in_progress_registrations = [
  %{
    training_activity_id: instructional_coaching_program.id,
    registrant_user_id: Enum.at(participant_users, 0).id,
    reviewer_user_id: coordinator_user.id,
    status: :approved,
    submitted_at: ~U[2026-07-05 09:00:00Z],
    reviewed_at: ~U[2026-07-08 10:00:00Z]
  },
  %{
    training_activity_id: instructional_coaching_program.id,
    registrant_user_id: Enum.at(participant_users, 1).id,
    reviewer_user_id: coordinator_user.id,
    status: :approved,
    submitted_at: ~U[2026-07-05 10:00:00Z],
    reviewed_at: ~U[2026-07-08 10:15:00Z]
  },
  %{
    training_activity_id: instructional_coaching_program.id,
    registrant_user_id: Enum.at(participant_users, 2).id,
    reviewer_user_id: coordinator_user.id,
    status: :approved,
    submitted_at: ~U[2026-07-06 08:00:00Z],
    reviewed_at: ~U[2026-07-08 10:30:00Z]
  }
]

completed_registrations = [
  %{
    training_activity_id: learning_recovery_bootcamp.id,
    registrant_user_id: Enum.at(participant_users, 0).id,
    reviewer_user_id: coordinator_user.id,
    status: :approved,
    submitted_at: ~U[2026-06-10 09:00:00Z],
    reviewed_at: ~U[2026-06-12 09:30:00Z]
  },
  %{
    training_activity_id: learning_recovery_bootcamp.id,
    registrant_user_id: Enum.at(participant_users, 1).id,
    reviewer_user_id: coordinator_user.id,
    status: :approved,
    submitted_at: ~U[2026-06-10 10:00:00Z],
    reviewed_at: ~U[2026-06-12 09:45:00Z]
  },
  %{
    training_activity_id: learning_recovery_bootcamp.id,
    registrant_user_id: Enum.at(participant_users, 3).id,
    reviewer_user_id: coordinator_user.id,
    status: :approved,
    submitted_at: ~U[2026-06-11 08:00:00Z],
    reviewed_at: ~U[2026-06-12 10:15:00Z]
  }
]

registrations =
  (future_registrations ++ in_progress_registrations ++ completed_registrations)
  |> Enum.map(&ensure_registration.(&1))

registration_for = fn training_title, user_email ->
  Enum.find(registrations, fn registration ->
    registration.training_activity_id ==
      Repo.get_by!(TrainingActivity, title: training_title).id and
      registration.registrant_user_id == Repo.get_by!(User, email: user_email).id
  end)
end

ensure_session = fn attrs ->
  case Repo.get_by(AttendanceSession,
         training_activity_id: attrs.training_activity_id,
         session_date: attrs.session_date,
         name: attrs.name
       ) do
    nil ->
      %AttendanceSession{}
      |> AttendanceSession.changeset(attrs)
      |> Repo.insert!()

    %AttendanceSession{} = attendance_session ->
      attendance_session
      |> AttendanceSession.changeset(attrs)
      |> Repo.update!()
  end
end

coaching_day_1 =
  ensure_session.(%{
    training_activity_id: instructional_coaching_program.id,
    name: "Day 1 Morning Session",
    session_date: ~D[2026-07-23],
    starts_at: ~T[08:00:00],
    ends_at: ~T[12:00:00],
    status: :closed,
    opened_by_user_id: coordinator_user.id,
    closed_by_user_id: coordinator_user.id
  })

coaching_day_2 =
  ensure_session.(%{
    training_activity_id: instructional_coaching_program.id,
    name: "Day 2 Workshop Session",
    session_date: ~D[2026-07-24],
    starts_at: ~T[08:00:00],
    ends_at: ~T[12:00:00],
    status: :open,
    opened_by_user_id: coordinator_user.id
  })

bootcamp_day_1 =
  ensure_session.(%{
    training_activity_id: learning_recovery_bootcamp.id,
    name: "Day 1 Opening Session",
    session_date: ~D[2026-07-01],
    starts_at: ~T[08:00:00],
    ends_at: ~T[12:00:00],
    status: :closed,
    opened_by_user_id: coordinator_user.id,
    closed_by_user_id: coordinator_user.id
  })

bootcamp_day_2 =
  ensure_session.(%{
    training_activity_id: learning_recovery_bootcamp.id,
    name: "Day 2 Workshop Session",
    session_date: ~D[2026-07-02],
    starts_at: ~T[08:00:00],
    ends_at: ~T[12:00:00],
    status: :closed,
    opened_by_user_id: coordinator_user.id,
    closed_by_user_id: coordinator_user.id
  })

ensure_attendance_record = fn attrs ->
  case Repo.get_by(AttendanceRecord,
         attendance_session_id: attrs.attendance_session_id,
         registration_id: attrs.registration_id
       ) do
    nil ->
      %AttendanceRecord{}
      |> AttendanceRecord.changeset(attrs)
      |> Repo.insert!()

    %AttendanceRecord{} = attendance_record ->
      attendance_record
      |> AttendanceRecord.changeset(attrs)
      |> Repo.update!()
  end
end

Enum.each(
  [
    %{
      attendance_session_id: coaching_day_1.id,
      registration_id:
        registration_for.("Instructional Coaching Program", "juan.cruz@deped.gov.ph").id,
      marked_by_user_id: coordinator_user.id,
      marked_at: ~U[2026-07-23 08:05:00Z],
      status: :present
    },
    %{
      attendance_session_id: coaching_day_1.id,
      registration_id:
        registration_for.("Instructional Coaching Program", "maria.santos@deped.gov.ph").id,
      marked_by_user_id: coordinator_user.id,
      marked_at: ~U[2026-07-23 08:12:00Z],
      status: :late
    },
    %{
      attendance_session_id: coaching_day_1.id,
      registration_id:
        registration_for.("Instructional Coaching Program", "ana.reyes@deped.gov.ph").id,
      marked_by_user_id: coordinator_user.id,
      marked_at: ~U[2026-07-23 08:20:00Z],
      status: :absent,
      notes: "Participant absent for the first session."
    },
    %{
      attendance_session_id: coaching_day_2.id,
      registration_id:
        registration_for.("Instructional Coaching Program", "juan.cruz@deped.gov.ph").id,
      marked_by_user_id: coordinator_user.id,
      marked_at: ~U[2026-07-24 08:04:00Z],
      status: :present
    },
    %{
      attendance_session_id: coaching_day_2.id,
      registration_id:
        registration_for.("Instructional Coaching Program", "maria.santos@deped.gov.ph").id,
      marked_by_user_id: coordinator_user.id,
      marked_at: ~U[2026-07-24 08:10:00Z],
      status: :present
    },
    %{
      attendance_session_id: bootcamp_day_1.id,
      registration_id:
        registration_for.("Learning Recovery and Acceleration Program", "juan.cruz@deped.gov.ph").id,
      marked_by_user_id: coordinator_user.id,
      marked_at: ~U[2026-07-01 08:03:00Z],
      status: :present
    },
    %{
      attendance_session_id: bootcamp_day_1.id,
      registration_id:
        registration_for.(
          "Learning Recovery and Acceleration Program",
          "maria.santos@deped.gov.ph"
        ).id,
      marked_by_user_id: coordinator_user.id,
      marked_at: ~U[2026-07-01 08:06:00Z],
      status: :present
    },
    %{
      attendance_session_id: bootcamp_day_1.id,
      registration_id:
        registration_for.(
          "Learning Recovery and Acceleration Program",
          "pedro.garcia@deped.gov.ph"
        ).id,
      marked_by_user_id: coordinator_user.id,
      marked_at: ~U[2026-07-01 08:25:00Z],
      status: :absent
    },
    %{
      attendance_session_id: bootcamp_day_2.id,
      registration_id:
        registration_for.("Learning Recovery and Acceleration Program", "juan.cruz@deped.gov.ph").id,
      marked_by_user_id: coordinator_user.id,
      marked_at: ~U[2026-07-02 08:02:00Z],
      status: :present
    },
    %{
      attendance_session_id: bootcamp_day_2.id,
      registration_id:
        registration_for.(
          "Learning Recovery and Acceleration Program",
          "maria.santos@deped.gov.ph"
        ).id,
      marked_by_user_id: coordinator_user.id,
      marked_at: ~U[2026-07-02 08:09:00Z],
      status: :late
    },
    %{
      attendance_session_id: bootcamp_day_2.id,
      registration_id:
        registration_for.(
          "Learning Recovery and Acceleration Program",
          "pedro.garcia@deped.gov.ph"
        ).id,
      marked_by_user_id: coordinator_user.id,
      marked_at: ~U[2026-07-02 08:20:00Z],
      status: :absent
    }
  ],
  ensure_attendance_record
)

ensure_evaluation_submission = fn attrs ->
  case Repo.get_by(EvaluationSubmission, registration_id: attrs.registration_id) do
    nil ->
      %EvaluationSubmission{}
      |> EvaluationSubmission.changeset(attrs)
      |> Repo.insert!()

    %EvaluationSubmission{} = evaluation_submission ->
      evaluation_submission
      |> EvaluationSubmission.changeset(attrs)
      |> Repo.update!()
  end
end

Enum.each(
  [
    %{
      registration_id:
        registration_for.("Learning Recovery and Acceleration Program", "juan.cruz@deped.gov.ph").id,
      submitted_by_user_id: Enum.at(participant_users, 0).id,
      submitted_at: ~U[2026-07-03 13:00:00Z],
      overall_rating: 5,
      feedback: "Very useful sessions on learning recovery strategies.",
      application_plan: "Apply remediation grouping in the first grading period."
    },
    %{
      registration_id:
        registration_for.(
          "Learning Recovery and Acceleration Program",
          "maria.santos@deped.gov.ph"
        ).id,
      submitted_by_user_id: Enum.at(participant_users, 1).id,
      submitted_at: ~U[2026-07-03 13:15:00Z],
      overall_rating: 4,
      feedback:
        "The workshop was practical and directly useful to classroom intervention planning.",
      application_plan: "Integrate the recovery monitoring checklist in weekly class review."
    }
  ],
  ensure_evaluation_submission
)

ensure_certificate_record = fn attrs ->
  case Repo.get_by(CertificateRecord, registration_id: attrs.registration_id) do
    nil ->
      %CertificateRecord{}
      |> CertificateRecord.changeset(attrs)
      |> Repo.insert!()

    %CertificateRecord{} = certificate_record ->
      certificate_record
      |> CertificateRecord.changeset(attrs)
      |> Repo.update!()
  end
end

Enum.each(
  [
    %{
      registration_id:
        registration_for.("Learning Recovery and Acceleration Program", "juan.cruz@deped.gov.ph").id,
      issued_by_user_id: coordinator_user.id,
      certificate_number: "000001",
      certificate_type: "Certificate of Completion",
      issued_on: ~D[2026-07-05],
      delivery_status: :available
    },
    %{
      registration_id:
        registration_for.(
          "Learning Recovery and Acceleration Program",
          "maria.santos@deped.gov.ph"
        ).id,
      issued_by_user_id: coordinator_user.id,
      certificate_number: "000002",
      certificate_type: "Certificate of Completion",
      issued_on: ~D[2026-07-05],
      delivery_status: :downloaded,
      downloaded_at: ~U[2026-07-06 09:00:00Z]
    }
  ],
  ensure_certificate_record
)

IO.puts("""

TRACMS demo account ready:
  email: #{demo_email}
  password: #{demo_password}

Additional sample accounts:
  division admin: division.admin@tracms.local / #{demo_password}
  coordinator: coordinator@tracms.local / #{demo_password}
  participant: juan.cruz@deped.gov.ph / #{demo_password}
  participant: maria.santos@deped.gov.ph / #{demo_password}
  participant: ana.reyes@deped.gov.ph / #{demo_password}
  participant: pedro.garcia@deped.gov.ph / #{demo_password}

Sample trainings created or refreshed:
  - Digital Education Trends (published)
  - Instructional Coaching Program (in progress)
  - Learning Recovery and Acceleration Program (completed)
  - Regional ICT Planning Workshop (draft)
""")
