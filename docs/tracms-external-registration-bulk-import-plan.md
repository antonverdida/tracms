# TRACMS External Registration Bulk Import Plan

## Goal

Reduce manager encoding work for external registration workflows by allowing batch staging of spreadsheet rows into the TRACMS external intake queue.

## Phase Scope

Implement a manager-side bulk import flow that:

- accepts pasted spreadsheet data from Google Sheets or simple CSV exports
- requires a header row for predictable field mapping
- stages all valid rows into `external_registration_submissions`
- reports row-level errors without discarding the whole batch

## Supported Fields

The bulk intake flow should support these columns:

- `full_name` or `name`
- `email`
- `employee_number`
- `office_name`, `office`, or `school`
- `source_reference` or `response_id`
- `special_requirements` or `notes`

## Rules

- require `full_name` and `email`
- keep bulk import as a staging workflow, not a direct registration insert
- auto-match TRACMS accounts by email the same way the manual intake form already does
- preserve the existing one-by-one intake form for corrections and small updates

## Non-Goals

- no direct Google Sheets API sync yet
- no file upload parser in this phase
- no background import jobs
