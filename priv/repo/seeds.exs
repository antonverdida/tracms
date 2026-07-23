alias Tracms.Accounts.{Role, User}
alias Tracms.Organization.{Division, Office}
alias Tracms.Repo

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
    |> User.email_changeset(%{email: demo_email})
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

IO.puts("""

TRACMS demo account ready:
  email: #{demo_email}
  password: #{demo_password}
""")
