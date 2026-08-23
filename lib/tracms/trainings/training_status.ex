defmodule Tracms.Trainings.TrainingStatus do
  @moduledoc false

  @values [
    :draft,
    :pending_division_approval,
    :pending_region_approval,
    :published,
    :registration_closed,
    :in_progress,
    :completed,
    :cancelled,
    :archived
  ]

  def values, do: @values
end
