# TRACMS Training Lifecycle Accuracy Plan

Date: July 24, 2026
Status: In progress

## Goal

Make the manager-facing training lifecycle pages read more like a real DepEd operational workflow without forcing unfinished backend features into the UI.

## Best Implementation Scope

Improve the pages that already exist in the workflow:

- training details
- attendance
- completion
- certificates

## What To Improve Now

### Training details

- add a stronger government-style record section
- show a clear workflow path from draft to archived
- surface current release status, ownership, and operational counts

### Attendance

- improve session naming guidance
- show the configured attendance method clearly
- present a more accurate selected-session summary including attendance rate and absent count
- keep QR attendance out of scope for now while stating that the current release remains manager-assisted

### Completion

- add certificate-readiness visibility
- distinguish completed participants from participants already issued certificates
- show incomplete requirements in a clearer summary

## Explicit Non-Goals For This Slice

- no QR scan workflow yet
- no approval audit-log table yet
- no new funding-source or provider tables yet
- no fake data fields just to match mockups

## Result

The workflow stays simple, professional, and accurate:

`Training Details -> Registration -> Attendance -> Completion -> Certificate`

but each page communicates government-style operational status more clearly.
